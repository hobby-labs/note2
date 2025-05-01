import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import axios from 'axios';

export const fetchCount = createAsyncThunk('items/fetchCount', async () => {
    const response = await axios.get('http://localhost:18080');
    return response.data;
});

interface CountObject {
    id: number;
    name: string;
    count: number;
}

interface CountState {
    loading: boolean;
    item: CountObject;
    error: string | null;
}

const initialState: CountState = {
    loading: false,
    item: {id: 0, name: 'No name', count: 0},
    error: null
};

const countSlice = createSlice({
    name: 'count',
    initialState,
    reducers: {},
    extraReducers: (builder) => {
        builder
            .addCase(fetchCount.pending, (state) => {
                state.loading = true;
            })
            .addCase(fetchCount.fulfilled, (state, action) => {
                state.loading = false;
                state.item = action.payload;
            })
            .addCase(fetchCount.rejected, (state, action) => {
                state.loading = false;
                state.error = action.error.message || 'Failed to fetch count';
            });
    }
});

export default countSlice.reducer;
