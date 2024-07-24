// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import { IDittoAdapter } from "src/interfaces/IDittoAdapter.sol";
import { IDittoEntryPoint } from "src/interfaces/IDittoEntryPoint.sol";
import { IMockTarget } from "src/interfaces/IMockTarget.sol";
import { IEntryPoint } from "src/entrypoint/interfaces/IEntryPoint.sol";
import { DittoAdapter } from "src/ditto-adapter/DittoAdapter.sol";
import { DittoEntryPoint } from "src/ditto-adapter/DittoEntryPoint.sol";
import { MockTarget } from "./mocks/MockTarget.sol";
import "src/interfaces/IERC7579Account.sol";
import { MODULE_TYPE_EXECUTOR } from "src/interfaces/IERC7579Module.sol";
import { PackedUserOperation } from "src/account-abstraction/interfaces/PackedUserOperation.sol";

interface IERC20 {
    function symbol() external view returns(string memory);
}

contract forkDEP is Test {
    
    string POLYGON_RPC_URL;
    address scaAddress;
    address entryPointAddressV06;
    IEntryPoint entryPointAddressV07;
    address defaultValidator;
    uint256 polygonFork;

    IDittoAdapter adapterModule;
    IDittoEntryPoint dittoEntryPoint;
    IMockTarget targetCounter;
    Vm.Wallet dittoOperator;

    IERC7579Account scaTarget;

    function newWallet(string memory name) internal returns (Vm.Wallet memory) {
        Vm.Wallet memory wallet = vm.createWallet(name);
        vm.label(wallet.addr, name);
        return wallet;
    }

    function setUp() public virtual {
        polygonFork = vm.createSelectFork("polygon");

        scaAddress = 0x088607996eC0002d63E178389Aa0342c82FA2164;
        scaTarget = IERC7579Account(scaAddress);
        
        entryPointAddressV06 = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        entryPointAddressV07 = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);
        defaultValidator = 0xBDcbeCc885D055233211f6594eBc19829d54a6c1;

        adapterModule = new DittoAdapter();
        dittoOperator = newWallet("DITTO_OPERATOR");
        dittoEntryPoint = new DittoEntryPoint(address(adapterModule), dittoOperator.addr);
        assertEq(adapterModule.dittoEntryPoint(), address(dittoEntryPoint));
        targetCounter = new MockTarget();
    }

    function getNonce(address account, address validator) internal view returns (uint256 nonce) {
        uint192 key = uint192(bytes24(bytes20(address(validator))));
        nonce = entryPointAddressV07.getNonce(address(account), key);
    }

    function getDefaultUserOp() internal pure returns (PackedUserOperation memory userOp) {
        userOp = PackedUserOperation({
            sender: address(0),
            nonce: 0,
            initCode: bytes(""),
            callData: bytes(""),
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            paymasterAndData: bytes(""),
            signature: abi.encodePacked(hex"41414141")
        });
    }

    function test_makeSure() public {
        // address entryPoint = IERC7579(scaAddress).entryPoint();
        //checking the symbol to make sure that the fork is working
        string memory symbol = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F).symbol(); 
        console.logString(symbol);
    }  

    function test_installAdapterModuleOnSCA() public {
        bytes memory initData = bytes("");

        bytes memory userOpCalldata = abi.encodeCall(
            IERC7579Account.installModule,
            (
                MODULE_TYPE_EXECUTOR,
                address(adapterModule),
                initData
            )
        );

        PackedUserOperation memory userOp = getDefaultUserOp();
        userOp.sender = address(scaAddress);
        userOp.nonce = getNonce(scaAddress, address(defaultValidator));
        userOp.callData = userOpCalldata;

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        // vm.prank(entryPointAddressV07);
        // scaTarget.installModule(MODULE_TYPE_EXECUTOR, address(adapterModule), "");
        entryPointAddressV07.handleOps(userOps, payable(address(0x69)));
    }
    
    
}