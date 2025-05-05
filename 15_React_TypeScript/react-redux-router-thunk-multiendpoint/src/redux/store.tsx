import { configureStore } from '@reduxjs/toolkit';
import countReducer from './countSlice';
import userListReducer from './userListSlice';

export const store = configureStore({
    reducer: {
        count: countReducer,
        userList: userListReducer
    }
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;