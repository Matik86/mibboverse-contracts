import { expect } from "chai";
import { network } from "hardhat";
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts'

const { viem } = await network.connect();

describe("GenesisNFT", () => {
  async function deployFixture() {
    const [owner, admin, user, other] = await viem.getWalletClients();

    const nft = await viem.deployContract("GenesisNFT", [
      "Genesis NFT",
      "OG",
      "Genesis of the Mibboverse",
      "ipfs://hidden.json"
    ]);

    const publicClient = await viem.getPublicClient();
    const chainId = await publicClient.getChainId();

    return { nft, owner, admin, user, other, chainId };
  }

  async function buildMintSignature({
    signer,
    chainId,
    contractAddress,
    to,
    nonce,
  }: {
    signer: any;
    chainId: number;
    contractAddress: string;
    to: string;
    nonce: bigint;
  }) {
    const domain = {
      name: "AdminMintableERC721",
      version: "1",
      chainId,
      verifyingContract: contractAddress,
    };

    const types = {
      MintRequest: [
        { name: "to", type: "address" },
        { name: "nonce", type: "uint256" },
      ],
    };

    const message = { to, nonce };

    return signer.signTypedData({
      domain,
      types,
      primaryType: "MintRequest",
      message,
    });
  }

  it("✅ deploys correctly", async () => {
    const { nft } = await deployFixture();

    const name = await nft.read.name();
    const symbol = await nft.read.symbol();
    const collectionName = await nft.read.collectionName();

    expect(name).to.equal("Genesis NFT");
    expect(symbol).to.equal("OG");
    expect(collectionName).to.equal("Genesis of the Mibboverse");
  });

  it("✅ successful mint with valid owner signature", async () => {
    const { nft, owner, user, chainId } = await deployFixture();

    const nonce = (await nft.read.nonces([user.account.address])) as unknown as bigint;

    const signature = await buildMintSignature({
      signer: owner,
      chainId,
      contractAddress: nft.address,
      to: user.account.address,
      nonce,
    });

    await nft.write.mintWithPermit([user.account.address, nonce, signature], {
      account: user.account,
    });

    const supply = await nft.read.totalSupply();
    expect(supply).to.equal(1n);

    const hasMinted = await nft.read.hasMinted([user.account.address]);
    expect(hasMinted).to.equal(true);
  });

  it("✅ owner can add admin and admin can mint", async () => {
    const { nft, owner, admin, user, chainId } = await deployFixture();

    await nft.write.setAdmin([admin.account.address, true], { account: owner.account });

    const nonce = (await nft.read.nonces([user.account.address])) as unknown as bigint;

    const signature = await buildMintSignature({
      signer: admin,
      chainId,
      contractAddress: nft.address,
      to: user.account.address,
      nonce,
    });

    await nft.write.mintWithPermit([user.account.address, nonce, signature], {
      account: user.account,
    });

    const supply = await nft.read.totalSupply();
    expect(supply).to.equal(1n);
    const hasMinted = await nft.read.hasMinted([user.account.address]);
    expect(hasMinted).to.equal(true);
  });

  it("✅ reveals metadata correctly and each token has unique URI after reveal", async () => {
    const { nft, owner, user, chainId } = await deployFixture();

    // Mint 2 tokens to verify the ID difference
    const mintFor = async (signer: any, to: any) => {
      const nonce = (await nft.read.nonces([to.account.address])) as unknown as bigint;
      const sig = await buildMintSignature({
        signer,
        chainId,
        contractAddress: nft.address,
        to: to.account.address,
        nonce,
      });
      await nft.write.mintWithPermit([to.account.address, nonce, sig], { account: to.account });
    };

    await mintFor(owner, user);

    const privateKey2 = generatePrivateKey();
    const account2 = privateKeyToAccount(privateKey2);

    const sig2 = await buildMintSignature({
      signer: owner,
      chainId,
      contractAddress: nft.address,
      to: account2.address,
      nonce: 0n,
    });

    await nft.write.mintWithPermit([account2.address, 0n, sig2]);

    // 2️⃣ Проверяем скрытую метадату
    const uriBeforeReveal1 = await nft.read.tokenURI([1n]);
    const uriBeforeReveal2 = await nft.read.tokenURI([2n]);
    expect(uriBeforeReveal1).to.equal("ipfs://hidden.json");
    expect(uriBeforeReveal2).to.equal("ipfs://hidden.json");

    // 3️⃣ Включаем reveal с baseURI
    await nft.write.setSingleMetadataMode([false], { account: owner.account });
    await nft.write.setBaseURI(["ipfs://bafybeig3g4zlxjzsvohmcljsgjwz422tzjpqft5pmq3kzq3a6a4sgkxkwm/"], { account: owner.account });
    await nft.write.setRevealed([true], { account: owner.account });

    // 4️⃣ Проверяем, что после ревила tokenURI уникален и формируется корректно
    const uriAfterReveal1 = await nft.read.tokenURI([1n]);
    const uriAfterReveal2 = await nft.read.tokenURI([2n]);

    expect(uriAfterReveal1).to.equal("ipfs://bafybeig3g4zlxjzsvohmcljsgjwz422tzjpqft5pmq3kzq3a6a4sgkxkwm/1.json");
    expect(uriAfterReveal2).to.equal("ipfs://bafybeig3g4zlxjzsvohmcljsgjwz422tzjpqft5pmq3kzq3a6a4sgkxkwm/2.json");

    // 5️⃣ Проверяем, что URI действительно различаются
    expect(uriAfterReveal1).to.not.equal(uriAfterReveal2);
  });

  it("✅ singleMetadataMode returns same URI for all tokens after reveal", async () => {
    const { nft, owner, user, chainId } = await deployFixture();

    const nonce = (await nft.read.nonces([user.account.address])) as unknown as bigint;
    const sig = await buildMintSignature({
      signer: owner,
      chainId,
      contractAddress: nft.address,
      to: user.account.address,
      nonce,
    });
    await nft.write.mintWithPermit([user.account.address, nonce, sig], { account: user.account });

    await nft.write.setRevealedURI(["ipfs://revealed.json"], { account: owner.account });
    await nft.write.setRevealed([true], { account: owner.account });

    const uri = await nft.read.tokenURI([1n]);
    expect(uri).to.equal("ipfs://revealed.json");
  });

  it("❌ mintWithPermit reverts with invalid signature (wrong signer)", async () => {
    const { nft, other, user, chainId } = await deployFixture();

    const nonce = (await nft.read.nonces([user.account.address])) as unknown as bigint;

    const signature = await buildMintSignature({
      signer: other, // neither the owner nor the admin
      chainId,
      contractAddress: nft.address,
      to: user.account.address,
      nonce,
    });

    let reverted = false;
    try {
      await nft.write.mintWithPermit([user.account.address, nonce, signature], {
        account: user.account,
      });
    } catch {
      reverted = true;
    }

    expect(reverted).to.be.true;
  });

  it("❌ mintWithPermit reverts if address already minted", async () => {
    const { nft, owner, user, chainId } = await deployFixture();

    const nonce = (await nft.read.nonces([user.account.address])) as unknown as bigint;

    const signature = await buildMintSignature({
      signer: owner,
      chainId,
      contractAddress: nft.address,
      to: user.account.address,
      nonce,
    });

    // First successful mint
    await nft.write.mintWithPermit([user.account.address, nonce, signature], {
      account: user.account,
    });

    // Second time - fall
    let reverted = false;
    try {
      await nft.write.mintWithPermit([user.account.address, nonce + 1n, signature], {
        account: user.account,
      });
    } catch {
      reverted = true;
    }

    expect(reverted).to.be.true;
  });
  
  it("❌ cannot mint after MAX_SUPPLY reached", async () => {
    const { nft, owner, chainId } = await deployFixture();

    // Bring supply to the limit
    for (let i = 0; i < 333; i++) {
      const privateKey = generatePrivateKey()
      const account = privateKeyToAccount(privateKey)

      const sig = await buildMintSignature({
        signer: owner,
        chainId,
        contractAddress: nft.address,
        to: account.address,
        nonce: 0n,
      });  
      await nft.write.mintWithPermit([account.address, 0n, sig]);
    }

    const nextPrivateKey = generatePrivateKey()
    const nextAccount = privateKeyToAccount(nextPrivateKey)

    const nextSig = await buildMintSignature({
      signer: owner,
      chainId,
      contractAddress: nft.address,
      to: nextAccount.address,
      nonce: 0n,
    });

    let reverted = false;
    try {
      await nft.write.mintWithPermit([nextAccount.address, 0n, nextSig]);
    } catch {
      reverted = true;
    }
    expect(reverted).to.be.true;
  });

  it("❌ non-owner cannot call onlyOwner functions", async () => {
    const { nft, user } = await deployFixture();

    async function expectRevert(tx: Promise<any>) {
        let reverted = false;
        try {
        await tx;
        } catch (err) {
        reverted = true;
        }
        expect(reverted).to.be.true;
    }

    await expectRevert(
        nft.write.setHiddenURI(["ipfs://newHidden.json"], { account: user.account })
    );

    await expectRevert(
        nft.write.setAdmin([user.account.address, true], { account: user.account })
    );

    await expectRevert(
        nft.write.setRevealed([true], { account: user.account })
    );
  });
});