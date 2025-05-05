import { createAsyncThunk, createSlice } from "@reduxjs/toolkit";
import axios from 'axios';

export const fetchUserList = createAsyncThunk('userList/fetchUserList', async () => {
    const response = await axios.get('http://localhost:18080/userList');
    return response.data;
});

interface User {
    id: number;
    name: string;
}

interface UserListState {
    loading: boolean;
    items: User[];
    error: string | null;
}

const initialState: UserListState = {
    loading: false,
    items: [],
    error: null
};

const userListSlice = createSlice({
    name: 'userList',
    initialState,
    reducers: {},
    extraReducers: (builder) => {
        builder
            .addCase(fetchUserList.pending, (state) => {
                state.loading = true;
            })
            .addCase(fetchUserList.fulfilled, (state, action) => {
                state.loading = false;
                state.items = action.payload;
            })
            .addCase(fetchUserList.rejected, (state, action) => {
                state.loading = false;
                state.error = action.error.message || 'Failed to fetch user list';
            });
    }
});

export default userListSlice.reducer;