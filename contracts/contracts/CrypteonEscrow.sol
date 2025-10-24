
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// OpenZeppelin imports via GitHub (no local npm needed in Remix or thirdweb CLI)
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/utils/ReentrancyGuard.sol";

contract CrypteonEscrow is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;        // ex: USDC on Base
    address public immutable beneficiary; // project treasury (Safe)
    uint256 public immutable unlockTime;  // 0 => admin release (owner) anytime

    bool public cancelled;                // if true => users can refund
    mapping(address => uint256) public deposits;

    event Deposited(address indexed user, uint256 amount);
    event Released(uint256 amount, address indexed to);
    event Cancelled();
    event Refunded(address indexed user, uint256 amount);

    constructor(
        address _token,
        address _beneficiary,
        uint256 _unlockTime,
        address _owner
    ) Ownable(_owner) {
        require(_token != address(0) && _beneficiary != address(0) && _owner != address(0), "zero addr");
        token = IERC20(_token);
        beneficiary = _beneficiary;
        unlockTime = _unlockTime; // if 0 => owner can release anytime
    }

    function deposit(uint256 amount) external nonReentrant {
        require(!cancelled, "cancelled");
        require(amount > 0, "zero");
        deposits[msg.sender] += amount;
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    function release() external nonReentrant onlyOwner {
        require(!cancelled, "cancelled");
        if (unlockTime > 0) {
            require(block.timestamp >= unlockTime, "locked");
        }
        uint256 bal = token.balanceOf(address(this));
        require(bal > 0, "empty");
        token.safeTransfer(beneficiary, bal);
        emit Released(bal, beneficiary);
    }

    function cancel() external onlyOwner {
        require(!cancelled, "already");
        cancelled = true;
        emit Cancelled();
    }

    function withdrawUser() external nonReentrant {
        require(cancelled, "not cancelled");
        uint256 amt = deposits[msg.sender];
        require(amt > 0, "none");
        deposits[msg.sender] = 0;
        token.safeTransfer(msg.sender, amt);
        emit Refunded(msg.sender, amt);
    }

    function tokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
