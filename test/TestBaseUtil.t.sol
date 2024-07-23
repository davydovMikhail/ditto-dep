// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import { MSABasic } from "src/MSABasic.sol";
import "src/interfaces/IERC7579Account.sol";
import "src/MSAFactory.sol";
import { BootstrapUtil, BootstrapConfig } from "./Bootstrap.t.sol";
import { MockValidator } from "./mocks/MockValidator.sol";
import { MockExecutor } from "./mocks/MockExecutor.sol";
import { ExecutionLib } from "src/lib/ExecutionLib.sol";
import {
    ModeLib, ModeCode, CallType, ExecType, ModeSelector, ModePayload
} from "src/lib/ModeLib.sol";
import { IEntryPoint } from "src/entrypoint/interfaces/IEntryPoint.sol";
import { EntryPoint } from "src/entrypoint/core/EntryPoint.sol";
import { PackedUserOperation } from "src/account-abstraction/interfaces/PackedUserOperation.sol";

// import "./dependencies/EntryPoint.sol";

contract TestBaseUtil is BootstrapUtil, Test {
    address constant public ENTRYPOINT_ADDR = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    // singletons
    MSABasic implementation;
    MSAFactory factory;
    IEntryPoint entrypoint;

    MockValidator defaultValidator;
    MockExecutor defaultExecutor;

    // MockTarget target;

    function setUp() public virtual {
        // Set up EntryPoint
        entrypoint = new EntryPoint();
        vm.etch(address(ENTRYPOINT_ADDR), address(entrypoint).code);
        // etchEntrypoint();
        entrypoint = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

        // Set up MSA and Factory
        implementation = new MSABasic();
        factory = new MSAFactory(address(implementation));

        // Set up Modules
        defaultExecutor = new MockExecutor();
        defaultValidator = new MockValidator();

    }

    function newWallet(string memory name) internal returns (Vm.Wallet memory) {
        Vm.Wallet memory wallet = vm.createWallet(name);
        vm.label(wallet.addr, name);
        return wallet;
    }

    function getAccountAndInitCode() internal returns (address account, bytes memory initCode) {
        // Create config for initial modules
        BootstrapConfig[] memory validators = makeBootstrapConfig(address(defaultValidator), "");
        BootstrapConfig[] memory executors = makeBootstrapConfig(address(defaultExecutor), "");
        BootstrapConfig memory hook = _makeBootstrapConfig(address(0), "");
        BootstrapConfig[] memory fallbacks = makeBootstrapConfig(address(0), "");

        // Create initcode and salt to be sent to Factory
        bytes memory _initCode =
            bootstrapSingleton._getInitMSACalldata(validators, executors, hook, fallbacks);
        bytes32 salt = keccak256("1");

        // Get address of new account
        account = factory.getAddress(salt, _initCode);

        // Pack the initcode to include in the userOp
        initCode = abi.encodePacked(
            address(factory),
            abi.encodeWithSelector(factory.createAccount.selector, salt, _initCode)
        );

        // Deal 1 ether to the account
        vm.deal(account, 1 ether);
    }

    function getNonce(address account, address validator) internal returns (uint256 nonce) {
        uint192 key = uint192(bytes24(bytes20(address(validator))));
        nonce = entrypoint.getNonce(address(account), key);
    }

    function getDefaultUserOp() internal returns (PackedUserOperation memory userOp) {
        userOp = PackedUserOperation({
            sender: address(0),
            nonce: 0,
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            paymasterAndData: bytes(""),
            signature: abi.encodePacked(hex"41414141")
        });
    }
}
