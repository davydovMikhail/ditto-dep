// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IExecutor, MODULE_TYPE_EXECUTOR } from "src/interfaces/IERC7579Module.sol";
import { IERC7579Account, Execution } from "src/interfaces/IERC7579Account.sol";
import { IDittoAdapter } from "src/interfaces/IDittoAdapter.sol";
import { ExecutionLib } from "src/lib/ExecutionLib.sol";
import { ModeLib } from "src/lib/ModeLib.sol";

contract DittoAdapter is IExecutor, IDittoAdapter {
    

    bytes32 private constant ENTRY_POINT_LOGIC_STORAGE_POSITION =
        keccak256("dittoadapter.storage");

    function _getLocalStorage()
        internal
        view
        returns (EntryPointStorage storage eps)
    {
        bytes32 position = ENTRY_POINT_LOGIC_STORAGE_POSITION;
        assembly ("memory-safe") {
            eps.slot := position
        }
    }

    function addWorkflow(
        bytes memory _callData,
        address _target,
        uint256 _count
    ) external {
        EntryPointStorage storage eps = _getLocalStorage();

        uint256 workflowKey;
        unchecked {
            workflowKey = eps.workflowIds++;
        }

        Workflow storage newWorkflow = eps.workflows[workflowKey];

        newWorkflow.workflow = _callData;
        newWorkflow.count = _count;
        newWorkflow.target = _target;
    }

    function executeFromDEP(
        address vault7579,
        uint256 workflowId
    )
        external
        returns (bytes[] memory returnData)
    {
        EntryPointStorage storage eps = _getLocalStorage();
        Workflow storage currentWorkflow = eps.workflows[workflowId];

        if(currentWorkflow.count == 0) {
            revert CounterLimitReached();
        }
        currentWorkflow.count--;
        
        return IERC7579Account(vault7579).executeFromExecutor(
            ModeLib.encodeSimpleSingle(), ExecutionLib.encodeSingle(currentWorkflow.target, 0, currentWorkflow.workflow)
        );
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
