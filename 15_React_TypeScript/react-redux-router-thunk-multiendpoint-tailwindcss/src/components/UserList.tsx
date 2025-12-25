import React, { useEffect } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { RootState, AppDispatch } from '../redux/store';
import { fetchUserList } from '../redux/userListSlice';

const UserList: React.FC = () => {

    const dispatch: AppDispatch = useDispatch();
    const { loading, items, error } = useSelector((state: RootState) => state.userList);

    console.log("Rendering UserList component");

    if (loading) return <div>Loading users...</div>;
    if (error) return (
        <div>
            <h1>Error loading users</h1>
            <button className="btn btn-gray" onClick={() => dispatch(fetchUserList())}>Refresh User List</button>
        </div>
    );

    return (
        <div>
            <h1>UserList: ({items.length} users)</h1>
            <ul>
                {items.map((user) => (
                    <li key={user.id}>
                        {user.name}
                    </li>
                ))}
            </ul>
            <button className="btn btn-emerald" onClick={() => dispatch(fetchUserList())}>Refresh User List</button>
        </div>
    );
};

export default UserList;
