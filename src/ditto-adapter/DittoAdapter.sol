// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { MODULE_TYPE_EXECUTOR } from "src/interfaces/IERC7579Module.sol";
import { IERC7579Account, Execution, ModeCode } from "src/interfaces/IERC7579Account.sol";
import { IDittoAdapter } from "src/interfaces/IDittoAdapter.sol";
import { ExecutionLib } from "src/lib/ExecutionLib.sol";
import { ModeLib } from "src/lib/ModeLib.sol";

contract DittoAdapter is IDittoAdapter {
    
    bytes32 private constant ENTRY_POINT_LOGIC_STORAGE_POSITION =
        keccak256("dittoadapter.storage");

    function _getLocalStorage()
        internal
        pure
        returns (EntryPointStorage storage eps)
    {
        bytes32 position = ENTRY_POINT_LOGIC_STORAGE_POSITION;
        assembly ("memory-safe") {
            eps.slot := position
        }
    }

    function addWorkflow(
        Execution[] memory _execution,
        uint256 _count
    ) external {
        EntryPointStorage storage eps = _getLocalStorage();

        uint256 workflowKey;
        unchecked {
            workflowKey = eps.workflowIds++;
        }

        WorkflowScenario storage newWorkflow = eps.workflows[workflowKey];
        bytes memory workflow = abi.encode(_execution);

        newWorkflow.workflow = workflow;
        newWorkflow.count = _count;
    }

    function executeFromDEP(
        address vault7579,
        uint256 workflowId
    )
        external
        returns (bytes[] memory returnData)
    {
        EntryPointStorage storage eps = _getLocalStorage();
        WorkflowScenario storage currentWorkflow = eps.workflows[workflowId];

        if(currentWorkflow.count == 0) {
            revert CounterLimitReached();
        }
        currentWorkflow.count--;

        (Execution[] memory executions) = abi.decode(currentWorkflow.workflow, (Execution[]));

        if(executions.length > 1) {
            return IERC7579Account(vault7579).executeFromExecutor(
                ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions)
            );
        } else {
            return IERC7579Account(vault7579).executeFromExecutor(
                ModeLib.encodeSimpleSingle(), ExecutionLib.encodeSingle(executions[0].target, executions[0].value, executions[0].callData)
            );
        }
    }

    function getWorkflow(uint256 workflowId) external view returns(WorkflowScenario memory wf) {
        wf = _getLocalStorage().workflows[workflowId];
    }

    function getNextWorkflowId() external view returns(uint256 lastId) {
        lastId = _getLocalStorage().workflowIds;
    }

    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function isModuleType(uint256 moduleTypeId) external view returns (bool) {
        return moduleTypeId == MODULE_TYPE_EXECUTOR;
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return false;
    }
}
