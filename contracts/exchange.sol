// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import the ERC-20 interface
import "./IERC20.sol";

contract TokenExchange {
    IERC20 public token; // The ERC-20 token

    struct ExchangeRequest {
        address user;
        uint256 tokenAmount;
        uint256 ethAmount;
        uint256 rate;
        bool allAtOnce;
    }

    ExchangeRequest[] public buyRequests;
    ExchangeRequest[] public sellRequests;

    constructor(address _token) {
        token = IERC20(_token);
    }

    // Users can submit a buy request to purchase tokens
    function submitBuyRequest(uint256 _tokenAmount, uint256 _ethAmount, bool allAtOnce) public {
        require(_tokenAmount > 0, "Invalid token amount");
        require(_ethAmount > 0, "Invalid ETH amount");
        require(token.transferFrom(msg.sender, address(this), _tokenAmount), "Token transfer failed");

        matchBuyRequests(msg.sender, _tokenAmount, _ethAmount, allAtOnce);
    }

    // Users can submit a sell request to exchange tokens for ETH
    function submitSellRequest(uint256 _tokenAmount, uint256 _ethAmount, bool allAtOnce) public {
        require(_tokenAmount > 0, "Invalid token amount");
        require(_ethAmount > 0, "Invalid ETH amount");

        matchSellRequests(msg.sender, _tokenAmount, _ethAmount, allAtOnce);
    }

    // Internal function to match buy requests with sell requests
    function matchBuyRequests(address _buyer, uint256 _tokenAmount, uint256 _ethAmount, bool allAtOnce) internal {
        uint256 rate = _tokenAmount / _ethAmount;
        for (uint256 i = 0; i < sellRequests.length; i++) {
            ExchangeRequest storage sellRequest = sellRequests[i];
            // don't buy expensive
            if(sellRequest.rate < rate){
                continue ;
            }
            if (sellRequest.ethAmount > _ethAmount && !sellRequest.allAtOnce) {
                // Transfer tokens and ETH
                payable(sellRequest.user).transfer(_ethAmount);
                token.transfer(_buyer, _tokenAmount);
                // 
                sellRequest.tokenAmount -= _tokenAmount;
                sellRequest.ethAmount -= _ethAmount;
                return ;
            }
            else if(sellRequest.ethAmount == _ethAmount) {
                // Transfer tokens and ETH
                payable(sellRequest.user).transfer(_ethAmount);
                token.transfer(_buyer, _tokenAmount);
                // 
                sellRequests[i] = sellRequests[sellRequests.length - 1];
                sellRequests.pop();
                return ;
            }
            else if (sellRequest.ethAmount < _ethAmount && !allAtOnce) {
                // Transfer tokens and ETH
                payable(sellRequest.user).transfer(sellRequest.ethAmount);
                token.transfer(_buyer, sellRequest.tokenAmount);
                //
                sellRequests[i] = sellRequests[sellRequests.length - 1];
                sellRequests.pop();
                //
                buyRequests.push(ExchangeRequest(_buyer, 
                                _tokenAmount - sellRequest.tokenAmount, 
                                _ethAmount - sellRequest.ethAmount,
                                rate,
                                allAtOnce));
                return ;
            }
        }
        // If no matching sell request found, add the buy request to the list
        buyRequests.push(ExchangeRequest(_buyer, _tokenAmount, _ethAmount, rate, allAtOnce));
    }

    // Internal function to match sell requests with buy requests
    function matchSellRequests(address _seller, uint256 _tokenAmount, uint256 _ethAmount, bool allAtOnce) internal {
        uint256 rate = _tokenAmount / _ethAmount;
        for (uint256 i = 0; i < buyRequests.length; i++) {
            ExchangeRequest storage buyRequest = buyRequests[i];
            // don't sell cheep
            if(buyRequest.rate > rate){
                continue ;
            }
            if (_ethAmount > buyRequest.ethAmount && !allAtOnce) {
                // Transfer tokens and ETH
                payable(_seller).transfer(buyRequest.ethAmount);
                token.transfer(buyRequest.user, buyRequest.tokenAmount);
                //
                buyRequests[i] = buyRequests[sellRequests.length - 1];
                buyRequests.pop(); 
                //
                sellRequests.push(ExchangeRequest(_seller, 
                                _tokenAmount - buyRequest.tokenAmount, 
                                _ethAmount - buyRequest.ethAmount, 
                                rate,
                                allAtOnce));
                return ;
            }
            else if(_ethAmount == buyRequest.ethAmount) {
                // Transfer tokens and ETH
                payable(_seller).transfer(buyRequest.ethAmount);
                token.transfer(buyRequest.user, buyRequest.tokenAmount);
                // 
                buyRequests[i] = buyRequests[sellRequests.length - 1];
                buyRequests.pop();
                return ;
            }
            else if (_ethAmount < buyRequest.ethAmount && !buyRequest.allAtOnce) {
                // Transfer tokens and ETH
                payable(_seller).transfer(_ethAmount);
                token.transfer(buyRequest.user, _tokenAmount);
                //
                buyRequest.tokenAmount -= _tokenAmount;
                buyRequest.ethAmount -= _ethAmount;
                return ;
            }
        }
        // If no matching buy request found, add the sell request to the list
        sellRequests.push(ExchangeRequest(_seller, _tokenAmount, _ethAmount, rate, allAtOnce));
    }
}