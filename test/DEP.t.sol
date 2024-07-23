// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import "./TestBaseUtil.t.sol";
import "src/interfaces/IERC7579Account.sol";
import "src/interfaces/IERC7579Module.sol";
import { IDittoAdapter } from "src/interfaces/IDittoAdapter.sol";
import { IDittoEntryPoint } from "src/interfaces/IDittoEntryPoint.sol";
import { IMockTarget } from "src/interfaces/IMockTarget.sol";
import { DittoAdapter } from "src/ditto-adapter/DittoAdapter.sol";
import { DittoEntryPoint } from "src/ditto-adapter/DittoEntryPoint.sol";
import { MODULE_TYPE_EXECUTOR } from "src/interfaces/IERC7579Module.sol";
import { MockTarget } from "./mocks/MockTarget.sol";

contract DittoEntryPointTest is TestBaseUtil {

    IDittoAdapter adapterModule;
    IDittoEntryPoint dittoEntryPoint;
    IMockTarget targetCounter;
    Vm.Wallet dittoOperator;
    
    function setUp() public override {
        super.setUp();
        adapterModule = new DittoAdapter();
        dittoOperator = newWallet("DITTO_OPERATOR");
        dittoEntryPoint = new DittoEntryPoint(address(adapterModule), dittoOperator.addr);
        assertEq(adapterModule.dittoEntryPoint(), address(dittoEntryPoint));
        targetCounter = new MockTarget();
    }

    function createSCAAccount() public returns (address) {
        bytes memory userOpCalldata = abi.encodePacked(uint(0));
        (address account, bytes memory initCode) = getAccountAndInitCode();
        // uint256 lengthBefore = account.code.length;
        // console.logUint(lengthBefore);
        PackedUserOperation memory userOp = getDefaultUserOp();
        userOp.sender = address(account);
        userOp.nonce = getNonce(account, address(defaultValidator));
        userOp.initCode = initCode;
        userOp.callData = userOpCalldata;
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        entrypoint.handleOps(userOps, payable(address(0x69)));
        // uint256 lengthAfter = account.code.length;
        // console.logUint(lengthAfter);
        return account;
    }

    function test_installAdapterModuleOnSCA() public returns(address accountSCA) {
        accountSCA = createSCAAccount();
        bytes memory initData = "";

        bytes memory userOpCalldata = abi.encodeCall(
            IERC7579Account.installModule,
            (
                MODULE_TYPE_EXECUTOR,
                address(adapterModule),
                initData
            )
        );

        PackedUserOperation memory userOp = getDefaultUserOp();
        userOp.sender = address(accountSCA);
        userOp.nonce = getNonce(accountSCA, address(defaultValidator));
        userOp.callData = userOpCalldata;

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        entrypoint.handleOps(userOps, payable(address(0x69)));

        assertEq(IERC7579Account(accountSCA).isModuleInstalled(MODULE_TYPE_EXECUTOR, address(adapterModule), ""), true);
    }

    function test_addingSimpleWorkflow() public returns(uint256) {
        bytes memory incrementValueOnTarget = abi.encodeCall(MockTarget.incrementValue, ());
        uint256 count = 10;
        uint256 nextWorkflowId = adapterModule.getNextWorkflowId();
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: address(targetCounter), value: 0, callData: incrementValueOnTarget });
        adapterModule.addWorkflow(
            executions,
            count
        );
        uint256 nextPlusOneWorkflowId = adapterModule.getNextWorkflowId();
        IDittoAdapter.WorkflowScenario memory wf = adapterModule.getWorkflow(nextWorkflowId);
        assertEq(nextWorkflowId + 1, nextPlusOneWorkflowId);
        bytes memory encodedExecutions = abi.encode(executions);

        assertEq(wf.workflow, encodedExecutions);
        assertEq(wf.count, count);
        return nextWorkflowId;
    }

    function test_addingBatchWorkflow() public returns(uint256) {
        bytes memory incrementValueOnTarget = abi.encodeCall(MockTarget.incrementValue, ());
        bytes memory incrementValueTwiceOnTarget = abi.encodeCall(MockTarget.incrementValueTwice, ());
        uint256 count = 10;
        uint256 nextWorkflowId = adapterModule.getNextWorkflowId();
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: address(targetCounter), value: 0, callData: incrementValueOnTarget });
        executions[1] = Execution({ target: address(targetCounter), value: 0, callData: incrementValueTwiceOnTarget });
        adapterModule.addWorkflow(
            executions,
            count
        );
        uint256 nextPlusOneWorkflowId = adapterModule.getNextWorkflowId();
        IDittoAdapter.WorkflowScenario memory wf = adapterModule.getWorkflow(nextWorkflowId);
        assertEq(nextWorkflowId + 1, nextPlusOneWorkflowId);
        bytes memory encodedExecutions = abi.encode(executions);

        assertEq(wf.workflow, encodedExecutions);
        assertEq(wf.count, count);
        return nextWorkflowId;
    }

    function testFuzz_Registration(uint256 workflowId) public {
        vm.prank(dittoOperator.addr);
        dittoEntryPoint.registerWorkflow(workflowId);
        assertEq(dittoEntryPoint.isRegistered(workflowId), true);
    }

    function test_runSimpleWorkflowFromDEP() public {
        uint256 valueBefore = targetCounter.getValue();
        address userAccount = test_installAdapterModuleOnSCA();
        uint256 workflowId = test_addingSimpleWorkflow();
        testFuzz_Registration(workflowId);
        dittoEntryPoint.runWorkflow(userAccount, workflowId);
        assertEq(targetCounter.getValue(), valueBefore + 1);
        IDittoEntryPoint.Workflow[] memory slice = dittoEntryPoint.getWorkflowSlice(0, 1);
        assertEq(slice[0].vaultAddress, userAccount);
        assertEq(slice[0].workflowId, workflowId);
    }

    function test_runBatchWorkflowFromDEP() public {
        uint256 valueBefore = targetCounter.getValue();
        address userAccount = test_installAdapterModuleOnSCA();
        uint256 workflowId = test_addingBatchWorkflow();
        testFuzz_Registration(workflowId);
        dittoEntryPoint.runWorkflow(userAccount, workflowId);
        assertEq(targetCounter.getValue(), valueBefore + 3);
        IDittoEntryPoint.Workflow[] memory slice = dittoEntryPoint.getWorkflowSlice(0, 1);
        assertEq(slice[0].vaultAddress, userAccount);
        assertEq(slice[0].workflowId, workflowId);
    }

    // function test_execBatch() public {
    //     // Create calldata for the account to execute
    //     bytes memory setValueOnTarget = abi.encodeCall(MockTarget.setValue, 1337);
    //     address target2 = address(0x420);
    //     uint256 target2Amount = 1 wei;
    //     // Create the executions
    //     Execution[] memory executions = new Execution[](2);
    //     executions[0] = Execution({ target: address(target), value: 0, callData: setValueOnTarget });
    //     executions[1] = Execution({ target: target2, value: target2Amount, callData: "" });
    //     // Encode the call into the calldata for the userOp
    //     bytes memory userOpCalldata = abi.encodeCall(
    //         IERC7579Account.execute,
    //         (ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions))
    //     );
    //     // Get the account, initcode and nonce
    //     (address account, bytes memory initCode) = getAccountAndInitCode();
    //     uint256 nonce = getNonce(account, address(defaultValidator));
    //     // Create the userOp and add the data
    //     PackedUserOperation memory userOp = getDefaultUserOp();
    //     userOp.sender = address(account);
    //     userOp.nonce = nonce;
    //     userOp.initCode = initCode;
    //     userOp.callData = userOpCalldata;
    //     // Create userOps array
    //     PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
    //     userOps[0] = userOp;
    // }

}
