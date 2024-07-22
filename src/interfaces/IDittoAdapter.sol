// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IExecutor } from "src/interfaces/IERC7579Module.sol";
import { Execution } from "src/interfaces/IERC7579Account.sol";

interface IDittoAdapter is IExecutor {

    error CounterLimitReached();

    struct WorkflowScenario {
        bytes workflow;
        uint256 count;
    }

    struct EntryPointStorage {
        mapping(uint256 => WorkflowScenario) workflows;
        uint256 workflowIds;
    }

    function addWorkflow(Execution[] memory _execution, uint256 _count) external;

    function executeFromDEP(address vault7579, uint256 workflowId) external returns (bytes[] memory returnData);

    function getWorkflow(uint256 workflowId) external view returns(WorkflowScenario memory wf);

    function getNextWorkflowId() external view returns(uint256 lastId);
}
