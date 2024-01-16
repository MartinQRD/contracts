// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IPermit2 } from "lifi/Interfaces/IPermit2.sol";
import { TransferrableOwnership } from "lifi/Helpers/TransferrableOwnership.sol";
import { LibAsset, IERC20 } from "lifi/Libraries/LibAsset.sol";

/// @title Permit2Proxy
/// @author LI.FI (https://li.fi)
/// @notice Proxy contract allowing gasless (Permit2-enabled) calls to our diamond contract
/// @custom:version 1.0.0
contract Permit2Proxy is TransferrableOwnership {
    string private constant _WITNESS_TYPE_STRING =
        "Witness witness)TokenPermissions(address token,uint256 amount)Witness(address tokenReceiver,address diamondAddress,bytes diamondCalldata)";
    bytes32 private constant _WITNESS_TYPEHASH =
        keccak256(
            "Witness(address tokenReceiver,address diamondAddress,bytes diamondCalldata)"
        );

    /// additional data signed by the user to make sure that their signature can only be used for a specific call
    struct Witness {
        address tokenReceiver;
        address diamondAddress;
        bytes diamondCalldata;
    }

    /// Storage ///
    IPermit2 public permit2;
    mapping(address => bool) public diamondWhitelist;

    /// Errors ///
    error DiamondAddressNotWhitelisted();
    error CallToDiamondFailed(bytes data);

    /// Events ///
    event WhitelistUpdated(address[] addresses, bool[] values);

    /// Constructor
    constructor(
        address permit2Address,
        address owner
    ) TransferrableOwnership(owner) {
        permit2 = IPermit2(permit2Address);
    }

    function gaslessWitnessDiamondCallSingleToken(
        IPermit2.PermitTransferFrom memory permit,
        uint256 amount,
        bytes memory witnessData,
        address senderAddress,
        bytes calldata signature
    ) external payable {
        // decode witnessData to obtain calldata and diamondAddress
        Witness memory witness = abi.decode(witnessData, (Witness));

        // transfer inputToken from user to this contract (aka the tokenReceiver) using Permit2 signature
        // we send tokenReceiver, diamondAddress and diamondCalldata as Witness to the permit contract to ensure:
        // a) that tokens can only be transferred to the tokenReceiver address which was signed by the user
        // b) that only the diamondAddress can be called which was signed by the user
        // c) that only the diamondCalldata can be executed which was signed by the user
        permit2.permitWitnessTransferFrom(
            permit,
            IPermit2.SignatureTransferDetails(witness.tokenReceiver, amount),
            senderAddress,
            keccak256(witnessData),
            _WITNESS_TYPE_STRING,
            signature
        );

        // maxApprove token to diamond if current allowance is insufficient
        LibAsset.maxApproveERC20(
            IERC20(permit.permitted.token),
            witness.diamondAddress,
            amount
        );

        // call our diamond to execute calldata
        _executeCalldata(witness.diamondAddress, witness.diamondCalldata);
    }

    function gaslessWitnessDiamondCallMultipleTokens(
        IPermit2.PermitBatchTransferFrom memory permit,
        uint256[] calldata amounts,
        bytes memory witnessData,
        address senderAddress,
        bytes calldata signature
    ) external payable {
        // TODO: add refunding of positive slippage / remaining tokens

        // decode witnessData to obtain calldata and diamondAddress
        Witness memory witness = abi.decode(witnessData, (Witness));

        // transfer multiple inputTokens from user to calling wallet using Permit2 signature
        // we send tokenReceiver, diamondAddress and diamondCalldata as Witness to the permit contract to ensure:
        // a) that tokens can only be transferred to the wallet calling this function (as signed by the user)
        // b) that only the diamondAddress can be called which was signed by the user
        // c) that only the diamondCalldata can be executed which was signed by the user
        IPermit2.SignatureTransferDetails[]
            memory transferDetails = new IPermit2.SignatureTransferDetails[](
                amounts.length
            );
        for (uint i; i < amounts.length; ) {
            transferDetails[i] = IPermit2.SignatureTransferDetails(
                address(this),
                amounts[i]
            );

            // ensure maxApproval to diamond
            LibAsset.maxApproveERC20(
                IERC20(permit.permitted[i].token),
                witness.diamondAddress,
                amounts[i]
            );

            // gas-efficient way to increase the loop counter
            unchecked {
                ++i;
            }
        }

        // call Permit2 contract and transfer all tokens
        permit2.permitWitnessTransferFrom(
            permit,
            transferDetails,
            senderAddress,
            keccak256(witnessData),
            _WITNESS_TYPE_STRING,
            signature
        );

        // call our diamond to execute calldata
        _executeCalldata(witness.diamondAddress, witness.diamondCalldata);
    }

    function _executeCalldata(
        address diamondAddress,
        bytes memory diamondCalldata
    ) private {
        // make sure diamondAddress is whitelisted
        // this limits the usage of this Permit2Proxy contracts to only work with our diamond contracts
        if (!diamondWhitelist[diamondAddress])
            revert DiamondAddressNotWhitelisted();

        // call diamond with provided calldata
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = diamondAddress.call{
            value: msg.value
        }(diamondCalldata);
        // throw error to make sure tx reverts if low-level call was unsuccessful
        if (!success) {
            revert CallToDiamondFailed(data);
        }
    }

    function updateWhitelist(
        address[] calldata addresses,
        bool[] calldata values
    ) external onlyOwner {
        for (uint i; i < addresses.length; ) {
            // update whitelist address value
            diamondWhitelist[addresses[i]] = values[i];

            // gas-efficient way to increase the loop counter
            unchecked {
                ++i;
            }
        }
        emit WhitelistUpdated(addresses, values);
    }
}
