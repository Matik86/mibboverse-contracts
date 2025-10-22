import { expect } from "chai";
import { network } from "hardhat";
import { encodeFunctionData } from "viem";

const { viem } = await network.connect();

describe("CrystalsV3 via Proxy", () => {
  async function deployFixture() {
  const [owner, admin, user, other] = await viem.getWalletClients();

  // Implementation deployment
  const crystalsImpl = await viem.deployContract("CrystalsV3", []);

  // Encode initialize for proxy
  const initData = encodeFunctionData({
    abi: crystalsImpl.abi,
    functionName: "initialize",
    args: ["Crystals", "CRYS"],
  });

  // Proxy deployment
  const proxy = await viem.deployContract("ProxyExample", [
    crystalsImpl.address,
    initData,
  ]);

  // Contract via proxy with ABI implementation
  const crystals = await viem.getContractAt("CrystalsV3", proxy.address);

  const publicClient = await viem.getPublicClient();
  const chainId = await publicClient.getChainId();

  return { crystals, owner, admin, user, other, chainId };
}

  async function buildMintSignature({
    signer,
    chainId,
    contractAddress,
    to,
    amount,
    nonce,
    deadline = 0n,
  }: {
    signer: any;
    chainId: number;
    contractAddress: string;
    to: string;
    amount: bigint;
    nonce: bigint;
    deadline?: bigint;
  }) {
    const domain = {
      name: "Crystals",
      version: "1",
      chainId,
      verifyingContract: contractAddress,
    };

    const types = {
      Mint: [
        { name: "to", type: "address" },
        { name: "amount", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" },
      ],
    };

    const message = { to, amount, nonce, deadline };

    return signer.signTypedData({
      domain,
      types,
      primaryType: "Mint",
      message,
    });
  }

  it("✅ deploy and initialize via proxy", async () => {
    const { crystals } = await deployFixture();

    const name = await crystals.read.name();
    const symbol = await crystals.read.symbol();

    expect(name).to.equal("Crystals");
    expect(symbol).to.equal("CRYS");
  });

  it("✅ owner can set admins", async () => {
    const { crystals, owner, admin } = await deployFixture();

    await crystals.write.setAdmin([await admin.account.address, true], {
      account: owner.account,
    });
    expect(await crystals.read.admins([await admin.account.address])).to.equal(true);

    await crystals.write.setAdmin([await admin.account.address, false], {
      account: owner.account,
    });
    expect(await crystals.read.admins([await admin.account.address])).to.equal(false);
  });

  it("✅ mintWithSignature works with valid admin signature", async () => {
    const { crystals, owner, user, chainId } = await deployFixture();

    const to = await user.account.address;
    const nonce = await crystals.read.nonces([to]) as unknown as bigint;
    const amount = 100n;

    await crystals.write.setAdmin([await owner.account.address, true], {
      account: owner.account,
    });

    const signature = await buildMintSignature({
      signer: owner,
      chainId,
      contractAddress: await crystals.address,
      to,
      amount,
      nonce,
    });

    await crystals.write.mintWithSignature([amount, nonce, 0n, signature], {
      account: user.account,
    });

    const balance = await crystals.read.balanceOf([to]);
    expect(balance).to.equal(amount);
  });

  it("✅ burn and adminBurnFrom", async () => {
    const { crystals, owner, admin, user, chainId } = await deployFixture();

    const to = await user.account.address;
    const amount = 100n;
    const nonce = await crystals.read.nonces([to]) as unknown as bigint;

    await crystals.write.setAdmin([await owner.account.address, true], {
      account: owner.account,
    });

    const signature = await buildMintSignature({
      signer: owner,
      chainId,
      contractAddress: await crystals.address,
      to,
      amount,
      nonce,
    });

    await crystals.write.mintWithSignature([amount, nonce, 0n, signature], {
      account: user.account,
    });
    
    await crystals.write.burn([30n], { account: user.account });
    expect(await crystals.read.balanceOf([to])).to.equal(70n);

    await crystals.write.setAdmin([await admin.account.address, true], {
      account: owner.account,
    });
    await crystals.write.adminBurnFrom([to, 20n], { account: admin.account });
    expect(await crystals.read.balanceOf([to])).to.equal(50n);
  });

  it("❌ mintWithSignature fails with invalid signature", async () => {
    const { crystals, other, user, chainId } = await deployFixture();

    const to = await user.account.address;
    const nonce = await crystals.read.nonces([to]) as unknown as bigint;
    const amount = 10n;

    const signature = await buildMintSignature({
      signer: other,
      chainId,
      contractAddress: await crystals.address,
      to,
      amount,
      nonce,
    });

    let reverted = false;
    try {
      await crystals.write.mintWithSignature([amount, nonce, 0n, signature], {
        account: user.account,
      });
    } catch {
      reverted = true;
    }
    expect(reverted).to.be.true;
  });
});
