import React from "react";
import { AppDispatch } from "../redux/store";
import { useSelector, useDispatch } from "react-redux";
import { RootState } from "../redux/store";
import { fetchCount } from "../redux/countSlice";

let GLOBAL_COUNTER = 0;

const Count: React.FC = () => {
    const dispatch: AppDispatch = useDispatch();
    const { loading, item, error } = useSelector((state: RootState) => state.count);

    const count = item.count;
    GLOBAL_COUNTER += count;

    console.log("Rendering Count component");
    console.log(item);
    console.log(loading);

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