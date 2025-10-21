///SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IUniversalRouter } from "@uniswap/universal-router/contracts/interfaces/IUniversalRouter.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";

/*///////////////////////////////////
            Interfaces
///////////////////////////////////*/
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPermit2 } from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import { IV4Router } from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";

/*///////////////////////////////////
            Libraries
///////////////////////////////////*/
import { SafeERC20 }  from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Commands } from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import { Actions } from "@uniswap/v4-periphery/src/libraries/Actions.sol";

contract SwapModule {
   /*///////////////////////////////////
            Variables de estado
    ///////////////////////////////////*/
    ///@notice Instancias de Uniswap
    IUniversalRouter public immutable i_router;
    IPermit2 public immutable i_permit2;
    
    /*///////////////////////////////////
                constructor
    ///////////////////////////////////*/
    constructor(address payable _router, address _permit2) {
        i_router = IUniversalRouter(_router);
        i_permit2 = IPermit2(_permit2);
    }

    /*///////////////////////////////////
                external
    ///////////////////////////////////*/
    /**
        @notice función para ejecutar swaps de inputs exactos
        @notice los outputs pueden variar según el valor mínimo _minAmountOut
        @param _key la información de la estructura Pool
        @param _amountIn la cantidad a intercambiar
        @param _minAmountOut la cantidad mínima aceptada después de un swap
        @param _deadline el tiempo máximo que un usuario acepta esperar para completar un swap
        @dev esta función no puede manejar ether y ERC20 al mismo tiempo.
    */
    function swapExactInputSingle(
        PoolKey calldata _key,
        uint128 _amountIn,
        uint128 _minAmountOut,
        uint48 _deadline
    ) external payable {
      bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));

      bytes memory actions = abi.encodePacked(
        uint8(Actions.SWAP_EXACT_IN_SINGLE),
        uint8(Actions.SETTLE_ALL),
        uint8(Actions.TAKE_ALL)
      );

      bytes[] memory params = new bytes[](3);
params[0] = abi.encode(
	IV4Router.ExactInputSingleParams({
		poolKey: _key,
    zeroForOne: true,
    amountIn: _amountIn,
    amountOutMinimum: _minAmountOut,
    hookData: bytes("")
  })
);
params[1] = abi.encode(_key.currency0, _amountIn);
params[2] = abi.encode(_key.currency1, _minAmountOut);

bytes[] memory inputs = new bytes[](1);

inputs[0] = abi.encode(actions, params);

bytes[] memory inputs = new bytes[](1);

inputs[0] = abi.encode(actions, params);

if(Currency.unwrap(_key.currency0) != address(0)){
	IERC20(Currency.unwrap(_key.currency0)).transferFrom(msg.sender, address(this), _amountIn);
	IERC20(Currency.unwrap(_key.currency0)).approve(address(i_permit2), _amountIn);
	i_permit2.approve(Currency.unwrap(_key.currency0), address(i_router), _amountIn, _deadline);
}

i_router.execute{value: _amountIn}(commands, inputs, _deadline);

    }
}

