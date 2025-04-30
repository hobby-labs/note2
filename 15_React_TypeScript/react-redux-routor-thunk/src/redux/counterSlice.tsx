import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import axios from 'axios';

export const fetchCount = createAsyncThunk('items/fetchCount', async () => {
    const response = await axios.get('http://localhost:18080');
    return response.data;
});

interface ItemState {
    loading: boolean;
    items: any[];
    error: string | null;
}

const initialState: ItemState = {
    loading: false,
    items: [{count: 0}],
    error: null
};

const dataSlice = createSlice({
    name: 'data',
    initialState,
    reducers: {},
    extraReducers: (builder) => {
        builder
            .addCase(fetchCount.pending, (state) => {
                state.loading = true;
            })
            .addCase(fetchCount.fulfilled, (state, action) => {
                state.loading = false;
                state.items = action.payload;
            })
            .addCase(fetchCount.rejected, (state, action) => {
                state.loading = false;
                state.error = action.error.message || 'Failed to fetch count';
            });
    }
});

export default dataSlice.reducer;
