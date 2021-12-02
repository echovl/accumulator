import { ethers } from "hardhat"
import { expect, use } from "chai"
import { solidity } from "ethereum-waffle"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

use(solidity)

const FIXED_BOO_REWARDS = 1_000_000
const BOO_ICE_RATIO = 2

describe("Accumulator", function () {
    let boo: any
    let ice: any
    let lp: any
    let router: any
    let masterchef: any
    let accumulator: any
    let owner: SignerWithAddress
    let acc1: SignerWithAddress
    let acc2: SignerWithAddress

    beforeEach(async function () {
        ;[owner, acc1, acc2] = await ethers.getSigners()

        const MockToken = await ethers.getContractFactory("MockToken")
        const Router = await ethers.getContractFactory("MockUniswapV2Router")
        const MasterChef = await ethers.getContractFactory("MockMasterChef")
        const Accumulator = await ethers.getContractFactory("Accumulator")

        boo = await MockToken.deploy("Boo Token", "BOO")
        ice = await MockToken.deploy("Ice Token", "ICE")
        lp = await MockToken.deploy("WFTM-USDC LP", "lpWFTM-USDC")

        await boo.deployed()
        await ice.deployed()
        await lp.deployed()

        masterchef = await MasterChef.deploy(
            lp.address,
            boo.address,
            FIXED_BOO_REWARDS
        )
        router = await Router.deploy(boo.address, ice.address, BOO_ICE_RATIO)

        await masterchef.deployed()
        await router.deployed()

        accumulator = await Accumulator.deploy(
            masterchef.address,
            router.address,
            boo.address,
            lp.address,
            1,
            [boo.address, ice.address]
        )

        await accumulator.deployed()
    })

    describe("deposit", function () {
        it("fails if not enough tokens", async function () {
            await expect(accumulator.deposit(100)).to.be.revertedWith(
                "Not enough funds"
            )
        })

        it("fails if not approved", async function () {
            lp.mint(owner.address, 1000)
            await expect(accumulator.deposit(100)).to.be.revertedWith("")
        })

        describe("success", function () {
            beforeEach(async function () {
                lp.mint(owner.address, 1000)
                lp.mint(acc1.address, 1000)
                await lp.approve(
                    accumulator.address,
                    ethers.constants.MaxUint256
                )
                await lp
                    .connect(acc1)
                    .approve(accumulator.address, ethers.constants.MaxUint256)
            })

            it("deposits lp tokens successfully", async function () {
                await accumulator.deposit(100)

                expect(await accumulator.balance(owner.address)).to.eq(100)
            })

            it("withdraw rewards after a second deposit", async function () {
                await accumulator.deposit(100)
                await accumulator.deposit(100)

                expect(await ice.balanceOf(owner.address)).to.eq(
                    FIXED_BOO_REWARDS * BOO_ICE_RATIO
                )
            })

            it("calculates rewards correctly if LP increases", async function () {
                await accumulator.deposit(100)
                await accumulator.connect(acc1).deposit(100)
                await accumulator.updateRewardDistribution()

                expect(await accumulator.pendingRewards(owner.address)).to.eq(
                    1.5 * FIXED_BOO_REWARDS * BOO_ICE_RATIO
                )
                expect(await accumulator.pendingRewards(acc1.address)).to.eq(
                    0.5 * FIXED_BOO_REWARDS * BOO_ICE_RATIO
                )
            })
        })
    })
})
