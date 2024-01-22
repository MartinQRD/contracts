// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScript } from "./utils/DeployScript.sol";
import { PeripheryRegistryFacet } from "lifi/Facets/PeripheryRegistryFacet.sol";

contract DeployPeripheryRegistryFacet2 is DeployScript {
    function _contractName() internal pure override returns (string memory) {
        return "PeripheryRegistryFacet";
    }

    function _creationCode() internal pure override returns (bytes memory) {
        return type(PeripheryRegistryFacet).creationCode;
    }

    function _getConstructorArgs(
        string calldata,
        string memory,
        address
    ) internal pure override returns (bytes memory) {}
}
