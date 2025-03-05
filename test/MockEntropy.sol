contract MockEntropy {
    function getFee(address) external view returns (uint128 feeAmount) {
        return 0.1 ether;
    }

    function requestWithCallback(address entropyProvider, bytes32 randomNumber) external payable returns (uint256) {
        return 654321;
    }

    function test() public {}
}
