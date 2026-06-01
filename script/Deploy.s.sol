// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Script } from "forge-std/Script.sol";
import { ERC721SeaDropCycled } from "../src/ERC721SeaDropCycled.sol";

contract Deploy is Script {
    function run() external {
        string memory name = vm.envString("NAME");
        string memory symbol = vm.envString("SYMBOL");
        uint256[] memory weights = _parseUints(vm.envString("WEIGHTS"));
        address[] memory allowedSeaDrop = _parseAddresses(
            vm.envString("ALLOWED_SEADROP")
        );

        vm.startBroadcast();
        new ERC721SeaDropCycled(name, symbol, allowedSeaDrop, weights);
        vm.stopBroadcast();
    }

    function _parseAddresses(string memory csv)
        internal
        pure
        returns (address[] memory)
    {
        bytes memory data = bytes(csv);
        if (data.length == 0) {
            return new address[](0);
        }

        uint256 count = 1;
        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] == ",") count++;
        }

        address[] memory addrs = new address[](count);
        uint256 start = 0;
        uint256 index = 0;

        for (uint256 i = 0; i <= data.length; i++) {
            bool atEnd = i == data.length;
            if (atEnd || data[i] == ",") {
                bytes memory slice = new bytes(i - start);
                for (uint256 j = 0; j < slice.length; j++) {
                    slice[j] = data[start + j];
                }
                addrs[index] = vm.parseAddress(string(slice));
                index++;
                start = i + 1;
            }
        }

        return addrs;
    }

    function _parseUints(string memory csv)
        internal
        pure
        returns (uint256[] memory)
    {
        bytes memory data = bytes(csv);
        if (data.length == 0) {
            return new uint256[](0);
        }

        uint256 count = 1;
        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] == ",") count++;
        }

        uint256[] memory values = new uint256[](count);
        uint256 start = 0;
        uint256 index = 0;

        for (uint256 i = 0; i <= data.length; i++) {
            bool atEnd = i == data.length;
            if (atEnd || data[i] == ",") {
                bytes memory slice = new bytes(i - start);
                for (uint256 j = 0; j < slice.length; j++) {
                    slice[j] = data[start + j];
                }
                values[index] = vm.parseUint(string(slice));
                index++;
                start = i + 1;
            }
        }

        return values;
    }
}
