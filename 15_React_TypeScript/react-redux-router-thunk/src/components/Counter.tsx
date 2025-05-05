import React from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { RootState, AppDispatch } from '../redux/store';
import { fetchCount } from '../redux/counterSlice';

const Counter: React.FC = () => {
    const dispatch: AppDispatch = useDispatch();
    const { loading, items, error } = useSelector((state: RootState) => state.counter);

    if (loading) {
        return <div>Loading...</div>;
    }
    if (error) {
        return <div>Error: {error}</div>;
    }

    return (
        <div>
            <p>Count: {items[0].count}</p>
            <button onClick={() => dispatch(fetchCount())}>GetCount</button>
        </div>
    );
};

export default Counter;
