import React from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { RootState, AppDispatch } from '../redux/store';
import { increment, decrement, incrementByAmount } from '../redux/counterSlice';

const Counter: React.FC = () => {
    const count = useSelector((state: RootState) => state.counter.value);
    const dispatch: AppDispatch = useDispatch();

    return (
        <div>
            <p>Count: {count}</p>
            <button onClick={() => dispatch(increment())}>Increment</button>
            <button onClick={() => dispatch(decrement())}>Decrement</button>
            <button onClick={() => dispatch(incrementByAmount(100))}>IncrementByAmount100</button>
        </div>
    );
};

export default Counter;
