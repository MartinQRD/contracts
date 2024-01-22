// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScript } from "./utils/DeployScript.sol";
import { HopFacetOptimized } from "lifi/Facets/HopFacetOptimized.sol";

contract DeployHopFacetOptimized2 is DeployScript {
    function _contractName() internal pure override returns (string memory) {
        return "HopFacetOptimized";
    }

    function _creationCode() internal pure override returns (bytes memory) {
        return type(HopFacetOptimized).creationCode;
    }

    function _getConstructorArgs(
        string calldata,
        string memory,
        address
    ) internal pure override returns (bytes memory) {}
}
