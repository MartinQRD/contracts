// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScript } from "./utils/DeployScript.sol";
import { stdJson } from "forge-std/Script.sol";
import { CBridgeFacetPacked } from "lifi/Facets/CBridgeFacetPacked.sol";

contract DeployCBridgeFacetPacked2 is DeployScript {
    using stdJson for string;

    function _contractName() internal pure override returns (string memory) {
        return "CBridgeFacetPacked";
    }

    function _creationCode() internal pure override returns (bytes memory) {
        return type(CBridgeFacetPacked).creationCode;
    }

    function _getConstructorArgs(
        string calldata _network,
        string memory,
        address _deployerAddress
    ) internal override returns (bytes memory) {
        string memory path = string.concat(root, "/config/cbridge.json");
        string memory json = vm.readFile(path);

        address cBridge = json.readAddress(
            string.concat(".", _network, ".cBridge")
        );

        return abi.encode(cBridge, _deployerAddress);
    }
}
