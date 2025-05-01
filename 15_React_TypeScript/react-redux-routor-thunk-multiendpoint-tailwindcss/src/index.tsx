import React from 'react';
import ReactDOM from 'react-dom/client';
import { Provider } from 'react-redux';
import { store } from './redux/store';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root') as HTMLElement);

/**
 * * Create render root.
 * * Create /src/App.tsx component and display it.
 * * Create components /src/components/Home.tsx and /src/components/Counter.tsx.
 * * Create props and pass them to the components.
 * * Create counterSlice "/src/redux/counterSlice.tsx", store of redux "/src/redux/store.tsx", wrap <Provider> with prop store index.tsx.
 */

root.render(
    <Provider store={store}>
        <App />
    </Provider>
);
