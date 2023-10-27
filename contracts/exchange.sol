// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ParsaTokenInterface{
    // Parsa uses The ERC-20 token as parent of its token
    function mint(address account, uint256 value) external ;
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract Exchange {
    
    address public owner;
    ParsaTokenInterface public token; 

    struct ExchangeRequest {
        address user;
        uint256 tokenAmount;
        uint256 weiAmount;
        uint256 rate; // wei per token
        bool allAtOnce;
    }

    ExchangeRequest[] public buyRequests;
    ExchangeRequest[] public sellRequests;

    event BuyRequestStored(
        address indexed buyer, 
        uint256 indexed weiAmount, 
        uint256 indexed tokenAmunt);

    event BuyRequestShrinked(
        address indexed buyer, 
        uint256 indexed newWeiAmount, 
        uint256 indexed newTokenAmunt);

    event BuyRequestMatched(
        address indexed buyer, 
        uint256 indexed lastWeiAmount, 
        uint256 indexed lastTokenAmunt);

    event SellRequestStored(
        address indexed seller, 
        uint256 indexed weiAmount, 
        uint256 indexed tokenAmunt);

    event SellRequestShrinked(
        address indexed seller, 
        uint256 indexed newWeiAmount, 
        uint256 indexed newTokenAmunt);

    event SellRequestMatched(
        address indexed seller, 
        uint256 indexed lastWeiAmount, 
        uint256 indexed lastTokenAmunt);

    // 
    // 
    // 
    //  Handling Token
    // 
    // 
    // 

    function airDrop(address user, uint256 amount) external onlyOwner {
        // later we can create a lottery
        token.mint(user, amount);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    constructor(address _token) {
        owner = msg.sender;
        token = ParsaTokenInterface(_token);
    }


    // 
    // 
    // 
    //  Emiting Buy Events
    // 
    // 
    // 

    function storeBuyRequest(ExchangeRequest memory buyRequest) internal returns (uint256) {
        buyRequests.push(buyRequest);
        ExchangeRequest memory temp;
        uint256 i = buyRequests.length - 2;
        for (; i >= 0; i--){
            temp = buyRequests[i];
            // if buyRequest rate not high enogh, swap with temp; OR
            // if buyRequest rate is the same as temp, 
            //swap only if buyRequest wei amount is less than temp
            if(temp.rate > buyRequest.rate ||
            (temp.rate == buyRequest.rate && temp.weiAmount > buyRequest.weiAmount)){
                buyRequests[i + 1] = temp;
                buyRequests[i] = buyRequest;
            }
            else 
                break ;
        }
        emit BuyRequestStored(buyRequest.user, buyRequest.weiAmount, buyRequest.tokenAmount);
        return i + 1;
    }

    function shrinkBuyRequest(
        ExchangeRequest memory buyRequest,
        ExchangeRequest memory shrink,
        uint256 index) internal returns (ExchangeRequest memory) {

        buyRequest.weiAmount -= shrink.weiAmount;
        buyRequest.tokenAmount -= shrink.tokenAmount;

        buyRequests[index] = buyRequest;

        emit BuyRequestShrinked(
            buyRequest.user, 
            buyRequest.weiAmount, 
            buyRequest.tokenAmount);
        
        return buyRequest;
    }

    function closeBuyRequest(
        ExchangeRequest memory buyRequest, 
        uint256 closedIndex) internal {

        for(uint256 i = closedIndex; i < buyRequests.length - 1; i++)
            buyRequests[i] = buyRequests[i-1];
        buyRequests.pop();
        
        emit BuyRequestMatched(
            buyRequest.user, 
            buyRequest.weiAmount, 
            buyRequest.tokenAmount);
    }

    // 
    // 
    // 
    //  Emiting Sell Events
    // 
    // 
    // 

    function storeSellRequest(ExchangeRequest memory sellRequest) internal returns (uint256) {
        sellRequests.push(sellRequest);
        ExchangeRequest memory temp;
        uint256 i = sellRequests.length - 2;
        for (; i >= 0; i--){
            temp = sellRequests[i];
            // if sellRequest rate not low enogh, swap with temp; OR
            // if sellRequest rate is the same as temp, 
            //swap only if sellRequest token amount is less than temp
            if(temp.rate < sellRequest.rate ||
            (temp.rate == sellRequest.rate && temp.tokenAmount > sellRequest.tokenAmount)){
                sellRequests[i + 1] = temp;
                sellRequests[i] = sellRequest;
            }
            else 
                break ;
        }
        emit SellRequestStored(sellRequest.user, sellRequest.weiAmount, sellRequest.tokenAmount);
        return i + 1;
    }

    function shrinkSellRequest(
        ExchangeRequest memory sellRequest,
        ExchangeRequest memory shrink,
        uint256 index) internal returns (ExchangeRequest memory) {

        sellRequest.weiAmount -= shrink.weiAmount;
        sellRequest.tokenAmount -= shrink.tokenAmount;

        sellRequests[index] = sellRequest;

        emit SellRequestShrinked(
            sellRequest.user, 
            sellRequest.weiAmount, 
            sellRequest.tokenAmount);

        return  sellRequest;
    }

    function closeSellRequest(
        ExchangeRequest memory sellRequest, 
        uint256 closedIndex) internal {

        for(uint256 i = closedIndex; i < sellRequests.length - 1; i++)
            sellRequests[i] = sellRequests[i-1];
        sellRequests.pop();

        emit SellRequestMatched(
            sellRequest.user, 
            sellRequest.weiAmount, 
            sellRequest.tokenAmount);
    }

    // 
    // 
    // 
    //  Handling Buy Requests (Payment Section)
    // 
    // 
    // 

    function submitBuyRequest(uint256 tokenAmount, uint256 weiAmount, bool allAtOnce) payable external {
        require(tokenAmount > 0, "Invalid token amount");
        require(weiAmount > 0, "Invalid Wei amount");
        require(msg.value > 0, "Insufficiant Wei amount");

        ExchangeRequest memory buyRequest = ExchangeRequest(
            msg.sender, 
            tokenAmount, 
            weiAmount, 
            weiAmount / tokenAmount, 
            allAtOnce
            );

        uint256 buyRI = storeBuyRequest(buyRequest);

        if (allAtOnce)
            matchSellRequest(buyRequest, buyRI);
        else
            matchSellRequests(buyRequest, buyRI);
    }

    function matchSellRequest(ExchangeRequest memory buyRequest, uint256 buyRI) internal {
        ExchangeRequest memory sellRequest;
        for (uint256 i = sellRequests.length - 1; i >= 0; i--){
            sellRequest = sellRequests[i];

            if(buyRequest.rate < sellRequest.rate)
                break ;
            if(sellRequest.allAtOnce && sellRequest.weiAmount > buyRequest.weiAmount)
                continue ;
            if(buyRequest.tokenAmount > sellRequest.tokenAmount) // buyer all at once
                continue ;

            if(buyRequest.tokenAmount < sellRequest.tokenAmount){
                payable(sellRequest.user).transfer(buyRequest.weiAmount);
                shrinkSellRequest(sellRequest, buyRequest, i);
            }
            else{ // buyRequest.tokenAmount == sellRequest.tokenAmount: because of buyer all at once
                payable(sellRequest.user).transfer(sellRequest.weiAmount);
                closeSellRequest(sellRequest, i);
                buyRequest.weiAmount -= sellRequest.weiAmount;

                // check for owner profit
                if(buyRequest.weiAmount > 0){
                    payable(owner).transfer(buyRequest.weiAmount);
                }
            }
            
            // transfer to buyer now (without lock)
            token.transferFrom(sellRequest.user, buyRequest.user, buyRequest.tokenAmount);
            closeBuyRequest(buyRequest, buyRI);

            return  ;
        }

        // lock weis to match later
        if(buyRequest.tokenAmount > 0){    
            payable(address(this)).transfer(buyRequest.weiAmount);
        }
    }

    function matchSellRequests(ExchangeRequest memory buyRequest, uint256 buyRI) internal {
        ExchangeRequest memory sellRequest;
        for (uint256 i = sellRequests.length - 1; i >= 0; i--){
            sellRequest = sellRequests[i];

            if(buyRequest.rate < sellRequest.rate)
                break ;
            if(sellRequest.allAtOnce && sellRequest.weiAmount > buyRequest.weiAmount)
                continue ;

            if(buyRequest.tokenAmount > sellRequest.tokenAmount){
                payable(sellRequest.user).transfer(sellRequest.weiAmount);
                closeSellRequest(sellRequest, i);

                // transfer to buyer now (without lock)
                token.transferFrom(sellRequest.user, buyRequest.user, sellRequest.tokenAmount);
                buyRequest = shrinkBuyRequest(buyRequest, sellRequest, buyRI);

                if(buyRequest.tokenAmount == 0){
                    // check for owner profit
                    if(buyRequest.weiAmount > 0){
                        payable(owner).transfer(buyRequest.weiAmount);
                    }
                    closeBuyRequest(buyRequest, buyRI);
                    return ;
                }
            }
            else{
                if(buyRequest.tokenAmount < sellRequest.tokenAmount){
                    payable(sellRequest.user).transfer(buyRequest.weiAmount);
                    shrinkSellRequest(sellRequest, buyRequest, i);
                }
                else{ // ==
                    payable(sellRequest.user).transfer(sellRequest.weiAmount);
                    closeSellRequest(sellRequest, i);
                    buyRequest.weiAmount -= sellRequest.weiAmount;

                    // check for owner profit
                    if(buyRequest.weiAmount > 0){
                        payable(owner).transfer(buyRequest.weiAmount);
                    }
                }

                // transfer to buyer now (without lock)
                token.transferFrom(sellRequest.user, buyRequest.user, buyRequest.tokenAmount);
                closeBuyRequest(buyRequest, buyRI);

                return   ;
            }            
        }

        // lock weis to match later
        if(buyRequest.tokenAmount > 0){    
            payable(address(this)).transfer(buyRequest.weiAmount);
        }
    }

    // 
    // 
    // 
    //  Handling Sell Requests (Payment Section)
    // 
    // 
    // 

    function submitSellRequest(uint256 tokenAmount, uint256 weiAmount, bool allAtOnce) external {
        require(tokenAmount > 0, "Invalid token amount");
        require(weiAmount > 0, "Invalid ETH amount");
        require(token.balanceOf(msg.sender) > 0, "Insufficiant token amount");

        ExchangeRequest memory sellRequest = ExchangeRequest(
            msg.sender, 
            tokenAmount, 
            weiAmount, 
            weiAmount / tokenAmount, 
            allAtOnce
            );

        uint256 sellRI = storeSellRequest(sellRequest);

        if (allAtOnce)
            matchBuyRequest(sellRequest, sellRI);
        else
            matchBuyRequests(sellRequest, sellRI);
    }

    function matchBuyRequest(ExchangeRequest memory sellRequest, uint256 sellRI) internal {
        ExchangeRequest memory buyRequest;
        for (uint256 i = buyRequests.length - 1; i >= 0; i--){
            buyRequest = buyRequests[i];

            if(buyRequest.rate < sellRequest.rate)
                break ;
            if(buyRequest.allAtOnce && buyRequest.tokenAmount > sellRequest.tokenAmount)
                continue ;
            if(sellRequest.weiAmount > buyRequest.weiAmount) // seller all at once
                continue ;               

            if(sellRequest.weiAmount < buyRequest.weiAmount){
                token.transfer(buyRequest.user, sellRequest.tokenAmount);
                buyRequest = shrinkBuyRequest(buyRequest, sellRequest, i);
                
                if(buyRequest.tokenAmount == 0){
                    // check for owner profit
                    if(buyRequest.weiAmount > 0){
                        payable(owner).transfer(buyRequest.weiAmount);
                    }
                    closeBuyRequest(buyRequest, i);
                }
            }
            else{ // buyRequest.weiAmount == sellRequest.weiAmount: because of seller all at once
                token.transfer(buyRequest.user, buyRequest.tokenAmount);
                closeBuyRequest(buyRequest, i);
            }
            
            // transfer to seller now (without lock)
            payable(sellRequest.user).transfer(sellRequest.weiAmount);
            closeSellRequest(sellRequest, sellRI);

            break ;
        }

        // check for owner profit
        if(buyRequest.tokenAmount == 0 && buyRequest.weiAmount > 0){
            payable(owner).transfer(buyRequest.weiAmount);
            return ;
        }

        // lock tokens to match later
        token.transfer(address(this), sellRequest.tokenAmount);
    }

    function matchBuyRequests(ExchangeRequest memory sellRequest, uint256 sellRI) internal {
        
    }
}