import React from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { RootState, AppDispatch } from '../redux/store';
import { fetchCount } from '../redux/countSlice';
import Count from './Count';
import UserList from './UserList.tsx';

const Data: React.FC = () => {

    return (
        <div className="grid grid-cols-1 mx-auto max-w-7xl justify-between lg:px-8">
            <Count />
            <UserList />
        </div>
    );
};

export default Data;
