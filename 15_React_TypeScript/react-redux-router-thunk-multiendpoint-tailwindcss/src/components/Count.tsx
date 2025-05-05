import React from "react";
import { AppDispatch, RootState } from "../redux/store";
import { useSelector, useDispatch } from "react-redux";
import { fetchCount } from "../redux/countSlice";

let GLOBAL_COUNTER = 0;

const Count: React.FC = () => {
    const dispatch: AppDispatch = useDispatch();
    const { loading, item, error } = useSelector((state: RootState) => state.count);

    const count = item.count;
    GLOBAL_COUNTER += count;

    if (loading) return <div>Loading...</div>;
    if (error) return (
        <div>
            <h1>Error loading countes</h1>
            <button className="btn btn-gray" onClick={() => dispatch(fetchCount())}>Increment</button>
        </div>
    );

    return (
        <div>
            <h1>Count: {GLOBAL_COUNTER} (Fetched count: {count})</h1>
            <button className="btn btn-blue" onClick={() => dispatch(fetchCount())}>Increment</button>
        </div>
    );
}

export default Count;
