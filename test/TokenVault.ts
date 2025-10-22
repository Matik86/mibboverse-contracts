import { expect } from "chai";
import { parseEther } from "viem";

import { network } from "hardhat";

const connection = await network.connect();
const { viem } = await network.connect();

describe("TokenVault", () => {
  async function deployFixture() {
    const [owner, admin, user, other] = await viem.getWalletClients();

    // Deploy a test ERC20 token
    const erc20 = await viem.deployContract("TestToken", ["TestToken", "TTK"]);

    // Deploy TokenVault
    const vault = await viem.deployContract("TokenVault", []);

    return { owner, admin, user, other, erc20, vault };
  }

  it("✅ initializes with owner as admin", async () => {
    const { owner, vault } = await deployFixture();
    const isAdmin = await vault.read.admins([owner.account.address]);
    expect(isAdmin).to.equal(true);
  });

  it("✅ owner can add and remove admins", async () => {
    const { vault, owner, admin } = await deployFixture();

    await vault.write.setAdmin([admin.account.address, true], { account: owner.account });
    expect(await vault.read.admins([admin.account.address])).to.equal(true);

    await vault.write.setAdmin([admin.account.address, false], { account: owner.account });
    expect(await vault.read.admins([admin.account.address])).to.equal(false);
  });

  it("✅ admin can allow a token for deposits", async () => {
    const { vault, erc20, owner } = await deployFixture();

    await vault.write.setAllowedToken([erc20.address, true], { account: owner.account });
    expect(await vault.read.allowedTokens([erc20.address])).to.equal(true);
  });

  it("✅ deposit works only with allowed tokens", async () => {
    const { vault, erc20, user, owner } = await deployFixture();

    // Mint tokens to user
    await erc20.write.mint([user.account.address, parseEther("1000")], { account: owner.account });

    // Allow token
    await vault.write.setAllowedToken([erc20.address, true], { account: owner.account });

    // Approve and deposit
    await erc20.write.approve([vault.address, parseEther("100")], { account: user.account });
    await vault.write.deposit([erc20.address, parseEther("100")], { account: user.account });

    const balance = await erc20.read.balanceOf([vault.address]);
    expect(balance).to.equal(parseEther("100"));
  });

  it("✅ claim works with a valid admin signature", async () => {
    const { vault, erc20, user, owner } = await deployFixture();

    // Allow token and fund vault
    await vault.write.setAllowedToken([erc20.address, true], { account: owner.account });
    await erc20.write.mint([vault.address, parseEther("1000")], { account: owner.account });

    const nonce = await vault.read.nonces([user.account.address]);
    const deadline = 0;
    const amount = parseEther("10");
    const publicClient = await viem.getPublicClient();
    const chainId = await publicClient.getChainId();

    // EIP-712 domain
    const domain = {
      name: "TokenVault",
      version: "1",
      chainId: chainId,
      verifyingContract: vault.address,
    };

    const types = {
      Claim: [
        { name: "to", type: "address" },
        { name: "token", type: "address" },
        { name: "amount", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" },
      ],
    };

    const message = {
      to: user.account.address,
      token: erc20.address,
      amount,
      nonce,
      deadline,
    };

    // Sign as owner (admin)
    const signature = await owner.signTypedData({
      domain,
      types,
      primaryType: "Claim",
      message,
    });

    // Execute claim
    await vault.write.claim([erc20.address, amount, nonce, deadline, signature], { account: user.account });

    const balance = await erc20.read.balanceOf([user.account.address]);
    expect(balance).to.equal(amount);
  });

  it("✅ only owner can withdraw tokens", async () => {
    const { vault, erc20, owner, other } = await deployFixture();

    await vault.write.setAllowedToken([erc20.address, true], { account: owner.account });
    await erc20.write.mint([vault.address, parseEther("100")], { account: owner.account });

    // ✅ The owner can withdraw
    await vault.write.withdraw([erc20.address, owner.account.address, parseEther("50")], { account: owner.account });

    const ownerBalance = await erc20.read.balanceOf([owner.account.address]);
    expect(ownerBalance).to.equal(parseEther("50"));

    // ❌ Another account cannot withdraw
    let errorCaught = false;
    try {
      await vault.write.withdraw([erc20.address, other.account.address, parseEther("10")], { account: other.account });
    } catch (err: any) {
      errorCaught = true;
      expect(err.message).to.include("OwnableUnauthorizedAccount");
      expect(err.message).to.include(other.account.address);
    }

    expect(errorCaught).to.be.true;

    const otherBalance = await erc20.read.balanceOf([other.account.address]);
    expect(otherBalance).to.equal(0n);
  });

  it("❌ claim fails with an invalid signature", async () => {
    const { vault, erc20, user, other, owner } = await deployFixture();

    await vault.write.setAllowedToken([erc20.address, true], { account: owner.account });
    await erc20.write.mint([vault.address, parseEther("100")], { account: owner.account });

    const nonce = await vault.read.nonces([user.account.address]);
    const deadline = 0;
    const amount = parseEther("5");
  
    const publicClient = await viem.getPublicClient();
    const chainId = await publicClient.getChainId();

    const domain = {
      name: "TokenVault",
      version: "1",
      chainId: chainId,
      verifyingContract: vault.address,
    };

    const types = {
      Claim: [
        { name: "to", type: "address" },
        { name: "token", type: "address" },
        { name: "amount", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" },
      ],
    };

    const message = {
      to: user.account.address,
      token: erc20.address,
      amount,
      nonce,
      deadline,
    };

    // Wrong signer (not admin)
    const signature = await other.signTypedData({
      domain,
      types,
      primaryType: "Claim",
      message,
    });
    
    let reverted = false;
    try {
      await vault.write.claim([erc20.address, amount, nonce, deadline, signature], { account: user.account });
    } catch (err: any) {
      // viem on Hardhat EDR may not provide revert reason, just mark as reverted
      if (err.name === "ContractFunctionExecutionError" || err.name === "TransactionExecutionError") {
        reverted = true;
      } else {
        throw err; // unexpected error
      }
    }

    if (!reverted) throw new Error("Claim did not revert as expected");
  });

  it("❌ cannot reuse the same signature (nonce replay)", async () => {
    const { vault, erc20, user, owner } = await deployFixture();

    await vault.write.setAllowedToken([erc20.address, true], { account: owner.account });
    await erc20.write.mint([vault.address, parseEther("100")], { account: owner.account });
    const publicClient = await viem.getPublicClient();

    const nonce = await vault.read.nonces([user.account.address]);
    const deadline = 0;
    const amount = parseEther("5");
    const chainId = await publicClient.getChainId();
    const domain = {
      name: "TokenVault",
      version: "1",
      chainId: chainId,
      verifyingContract: vault.address,
    };

    const types = {
      Claim: [
        { name: "to", type: "address" },
        { name: "token", type: "address" },
        { name: "amount", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" },
      ],
    };

    const message = {
      to: user.account.address,
      token: erc20.address,
      amount,
      nonce,
      deadline,
    };

    const signature = await owner.signTypedData({
      domain,
      types,
      primaryType: "Claim",
      message,
    });

    // First claim succeeds
    await vault.write.claim([erc20.address, amount, nonce, deadline, signature], { account: user.account });

    // Second claim with same nonce must fail
    let reverted = false;
    try {
      await vault.write.claim([erc20.address, amount, nonce, deadline, signature], { account: user.account });
    } catch (err: any) {
      // viem on Hardhat EDR may not provide revert reason, just mark as reverted
      if (err.name === "ContractFunctionExecutionError" || err.name === "TransactionExecutionError") {
        reverted = true;
      } else {
        throw err; // unexpected error
      }
    }

    if (!reverted) throw new Error("Claim did not revert as expected");
  });
});
