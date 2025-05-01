import React from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { RootState, AppDispatch } from '../redux/store';
import { fetchCount } from '../redux/countSlice';
import Count from './Count';
import UserList from './UserList.tsx';

const Data: React.FC = () => {

    return (
        <div>
            <Count />
            <UserList />
        </div>
    );
};

export default Data;
