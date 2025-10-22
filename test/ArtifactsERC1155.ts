import { expect } from "chai";
import { network } from "hardhat";

const { viem } = await network.connect();

describe("ArtifactsERC1155", () => {
  async function deployFixture() {
    const [owner, admin, user, other] = await viem.getWalletClients();

    // Deploy
    const artifacts = await viem.deployContract("ArtifactsERC1155", []);

    const publicClient = await viem.getPublicClient();
    const chainId = await publicClient.getChainId();

    return { artifacts, owner, admin, user, other, chainId };
  }

  async function buildMintSignature({
    signer,
    chainId,
    contractAddress,
    to,
    id,
    amount,
    nonce,
  }: {
    signer: any;
    chainId: number;
    contractAddress: string;
    to: string;
    id: bigint;
    amount: bigint;
    nonce: bigint;
  }) {
    const domain = {
      name: "AdminMintableERC1155",
      version: "1",
      chainId,
      verifyingContract: contractAddress,
    };

    const types = {
      MintRequest: [
        { name: "to", type: "address" },
        { name: "id", type: "uint256" },
        { name: "amount", type: "uint256" },
        { name: "nonce", type: "uint256" },
      ],
    };

    const message = { to, id, amount, nonce };

    return signer.signTypedData({
      domain,
      types,
      primaryType: "MintRequest",
      message,
    });
  }

  it("✅ deploy with correct name and symbol", async () => {
    const { artifacts } = await deployFixture();

    const name = await artifacts.read.name();
    const symbol = await artifacts.read.symbol();

    expect(name).to.equal("Artifacts of the Mibboverse");
    expect(symbol).to.equal("ATF");
  });

  it("✅ owner can set and remove admins", async () => {
    const { artifacts, owner, admin } = await deployFixture();

    await artifacts.write.setAdmin([admin.account.address, true], {
      account: owner.account,
    });
    expect(await artifacts.read.admins([admin.account.address])).to.equal(true);

    await artifacts.write.setAdmin([admin.account.address, false], {
      account: owner.account,
    });
    expect(await artifacts.read.admins([admin.account.address])).to.equal(false);
  });

  it("✅ owner can set token metadata", async () => {
    const { artifacts, owner } = await deployFixture();

    await artifacts.write.setTokenMetadata(
      [1n, "Magic Sword", "ipfs://token/1"],
      { account: owner.account }
    );

    const uri = await artifacts.read.uri([1n]);
    const name = await artifacts.read.token_name([1n]);

    expect(uri).to.equal("ipfs://token/1");
    expect(name).to.equal("Magic Sword");
  });

  it("✅ mintWithPermit works with valid owner signature", async () => {
    const { artifacts, owner, user, chainId } = await deployFixture();

    const nonce = (await artifacts.read.nonces([user.account.address])) as unknown as bigint;
    const id = 1n;
    const amount = 10n;

    const signature = await buildMintSignature({
      signer: owner,
      chainId,
      contractAddress: artifacts.address,
      to: user.account.address,
      id,
      amount,
      nonce,
    });

    await artifacts.write.mintWithPermit(
      [user.account.address, id, amount, nonce, signature],
      { account: user.account }
    );

    const balance = await artifacts.read.balanceOf([
      user.account.address,
      id,
    ]);
    expect(balance).to.equal(amount);
  });

  it("✅ user can burn their tokens", async () => {
    const { artifacts, owner, user, chainId } = await deployFixture();

    const nonce = (await artifacts.read.nonces([user.account.address])) as unknown as bigint;
    const id = 1n;
    const amount = 5n;

    const signature = await buildMintSignature({
      signer: owner,
      chainId,
      contractAddress: artifacts.address,
      to: user.account.address,
      id,
      amount,
      nonce,
    });

    await artifacts.write.mintWithPermit(
      [user.account.address, id, amount, nonce, signature],
      { account: user.account }
    );

    // Burn 2 tokens
    await artifacts.write.burn([user.account.address, id, 2n], {
      account: user.account,
    });

    const balance = await artifacts.read.balanceOf([
      user.account.address,
      id,
    ]);
    expect(balance).to.equal(3n);
  });

  it("❌ mintWithPermit reverts with invalid signature (wrong signer)", async () => {
    const { artifacts, other, user, chainId } = await deployFixture();

    const nonce = (await artifacts.read.nonces([user.account.address])) as unknown as bigint;
    const id = 1n;
    const amount = 10n;

    // Signs not the owner nor admin
    const signature = await buildMintSignature({
      signer: other,
      chainId,
      contractAddress: artifacts.address,
      to: user.account.address,
      id,
      amount,
      nonce,
    });

    // The attempt to mint should fail with a revert.
    let reverted = false;
    try {
      await artifacts.write.mintWithPermit(
        [user.account.address, id, amount, nonce, signature],
        { account: user.account }
      );
    } catch {
      reverted = true;
    }

    expect(reverted).to.be.true;
  });
});