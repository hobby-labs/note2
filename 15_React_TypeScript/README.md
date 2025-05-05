# Create new project 

```bash
$ mkdir react-ts-webpack
$ cd react-ts-webpack
$ npm init -y
$ ls -l package.json
> ... package.json
```

```bash
$ npm install --save react react-dom
$ npm install --save-dev typescript @types/react @types/react-dom
$ npm install --save-dev webpack webpack-cli webpack-dev-server ts-loader
$ npm install --save-dev @babel/core @babel/preset-env @babel/preset-react @babel/preset-typescript babel-loader
```

* webpack.config.js
```javascript
const path = require('path');

module.exports = {
  entry: './src/index.tsx',
  output: {
    filename: 'bundle.js',
    path: path.resolve(__dirname, 'dist')
  },
  resolve: {
    extensions: ['.tsx', '.ts', '.js']
  }
};
```

* .babelrc
```json
{
  "presets": [
    "@babel/preset-env",
    "@babel/preset-react",
    "@babel/preset-typescript"
  ]
}
```

Babel presets are ...
* `@babel/preset-env` -> Converting modern ECMAScript to JavaScript that can run on general browsers.
* `@babel/preset-react` -> Converting JSX to JavaScript.
* `@babel/preset-typescript` -> Converting TypeScript to JavaScript. 

ESLint を導入します。

```bash
$ npm install --save-dev eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin
$ npm install --save-dev prettier eslint-config-prettier eslint-plugin-react eslint-plugin-prettier
$ git init --initial-branch=main
$ echo "node_modules" >  .gitignore
$ echo ".eslintcache" >> .gitignore
$ git add .
$ git commit -m "init"
$ npx mrm lint-staged
```

* eslint.config.mjs (9.0.0 以降)
```javascript
import { ESLint } from 'eslint';
import tsPlugin from '@typescript-eslint/eslint-plugin';
import tsParser from '@typescript-eslint/parser';
import reactPlugin from 'eslint-plugin-react';
import prettierPlugin from 'eslint-plugin-prettier';

export default [
  {
    files: ['**/*.ts', '**/*.tsx'],
    languageOptions: {
      parser: tsParser,
      parserOptions: {
        sourceType: 'module',
        ecmaVersion: 2019,
        tsconfigRootDir: "functions",
        project: ['./tsconfig.eslint.json'],
      },
    },
    plugins: {
      '@typescript-eslint': tsPlugin,
      react: reactPlugin,
      prettier: prettierPlugin,
    },
    rules: {
      ...tsPlugin.configs.recommended.rules,
      ...tsPlugin.configs['recommended-requiring-type-checking'].rules,
      ...reactPlugin.configs.recommended.rules,
      'prettier/prettier': 'error',
    },
  },
  {
    files: ['**/*.js', '**/*.jsx'],
    languageOptions: {
      ecmaVersion: 2019,
      sourceType: 'module',
    },
    plugins: {
      react: reactPlugin,
      prettier: prettierPlugin,
    },
    rules: {
      ...reactPlugin.configs.recommended.rules,
      'prettier/prettier': 'error',
    },
  },
];
```

* webpack.config.js
```diff
 const path = require('path');
 
 module.exports = {
   entry: './src/index.tsx',
   output: {
     filename: 'bundle.js',
     path: path.resolve(__dirname, 'dist')
   },
   resolve: {
     extensions: ['.tsx', '.ts', '.js']
-   }
+  },
+  module: {
+    rules: [
+      {
+        test: /\.(ts|tsx)$/, 
+        exclude: /node_modules/,
+        use: 'babel-loader'
+      }
+    ]
+  }
 };
```

```bash
$ mkdir ./src
```

* src/index.html
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Webpack React TS</title>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
```

Install `html-webpack-plugin`.

```bash
$ npm install --save-dev html-webpack-plugin
```

* webpack.config.js
```diff
 const path = require('path');
+const HtmlWebpackPlugin = require('html-webpack-plugin');
 
 module.exports = {
   entry: './src/index.tsx',
   output: {
     filename: 'bundle.js',
     path: path.resolve(__dirname, 'dist')
   },
   resolve: {
     extensions: ['.tsx', '.ts', '.js']
   },
   module: {
     rules: [
       {
         test: /\.(ts|tsx)$/, 
         exclude: /node_modules/,
         use: 'babel-loader'
       }
     ]
-  }
+  },
+  plugins: [
+    new HtmlWebpackPlugin({
+      template: './src/index.html'
+    })
+  ]
 };
```

typesync を導入します。

```bash
$ npm install --save-dev typesync
```

* package.json  (一部抜粋)
```json
{
  ......
  "scripts": {
    ......
    "preinstall": "typesync || :"
  },
  ......
}
```

`html-webpack-plugin` は、JavaScript が組み込まれたHTML を`dist` ディレクトリに作成します。
複数のJavaScript ファイルを組み込み、HTML ファイルとして提供することを自動化します。

* src/index.tsx
```typescript
import React from 'react';
import ReactDOM from 'react-dom/client'

const root = ReactDOM.createRoot(document.getElementById('root') as HTMLElement);

root.render(
    <div>
        <h1>Hello, React!</h1>
    </div>
);
```

* package.json  (一部抜粋)
```json
{
  ......
  "scripts": {
    ......
    "start": "webpack serve --open --mode development",
    "build": "webpack --mode production"
  },
  ......
}
```

`production` オプションで、production モードでビルドします。
これは、資材の縮小化や無駄なコードの削除を行い、商用環境へ向けた最適化されたビルドを生成します。

```bash
$ npm start
## visit http://localhost:8080
```



# components を作成する
`src/index.tsx` を、各コンポーネントに分割します。
`App`, `Home`, `Data` コンポーネントを作成します。

```bash
$ mkdir src/components
```

* src/components/Home.tsx
```typescript
import React from 'react';

const Home: React.FC = () => {
    return (
        <div>
            <h2>Home component.</h2>
        </div>
    );
};

export default Home;
```

* src/components/Data.tsx
```typescript
import React from 'react';

const Data: React.FC = () => {
    return (
        <div>
            <h2>Data component.</h2>
        </div>
    );
};

export default Data;
```

* src/App.tsx
```typescript
import React from 'react';

import Home from './components/Home';
import Data from './components/Data';

const App: React.FC = () => {
    return (
        <div>
            <h1>Hello, React!</h1>
            <Home />
            <Data />
        </div>
    );
};

export default App;
```

* src/index.tsx
```typescript
 import React from 'react';
 import ReactDOM from 'react-dom/client'
+import App from './App';

 const root = ReactDOM.createRoot(document.getElementById('root') as HTMLElement);

 root.render(
     <div>
-        <h1>Hello, React!</h1>
+        <App />
     </div>
 );
```

```bash
$ npm start
```


# props を渡す

* src/components/Home.tsx
```typescript
 import React from 'react';

-const Home: React.FC = () => {
+type HomeProps = {
+  name: string;
+}
+
+const Home: React.FC<HomeProps> = ({ name }) => {
     return (
         <div>
-            <h2>Home component.</h2>
+            <h1>{name} in component.</h1>
+            This is a test page.
         </div>
     );
-};
+}
 
 export default Home;
```

* src/App.tsx
```typescript
 import React from 'react';
 
 import Home from './components/Home';
 import Data from './components/Data';
 
 const App: React.FC = () => {
     return (
         <div>
             <h1>Hello, React!</h1>
-            <Home />
+            <Home name="My Home" />
             <Data />
         </div>
     );
 };
 
 export default App;
```



# React Router を導入する

```bash
$ npm install --save react-router-dom
```

* src/App.tsx
```typescript
import React from 'react';
import { BrowserRouter as Router, Route, Routes, Link } from 'react-router-dom';

import Home from './components/Home';
import Data from './components/Data';

const App: React.FC = () => {
    return (
        <Router>
            <nav>
                <Link to="/">Home</Link> | <Link to="/data">Data</Link>
            </nav>
            <Routes>
                <Route path="/" element={<Home name="My Home" />} />
                <Route path="/data" element={<Data />} />
            </Routes>
        </Router>
    );
};

export default App;
```



# Redux を導入する

```bash
$ npm install --save react-redux @reduxjs/toolkit
$ mkdir src/redux
```

* src/redux/countSlice.tsx
```typescript
import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';

export const fetchCount = createAsyncThunk('items/fetchCount', async () => {
    return {id: 1, name: 'Item 1', count: 1};
})

interface CountObject {
    count: number;
}

interface CountState {
    loading: boolean;
    item: CountObject;
}

const initialState: CountState = {
    loading: false,
    item: {id: 0, name: 'No name', count: 0},
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
            });
    }
});

export default countSlice.reducer;
```

* src/redux/store.ts
```
import { configureStore } from '@reduxjs/toolkit';
import countReducer from './countSlice';

export const store = configureStore({
    reducer: {
        count: countReducer
    }
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
```

* src/components/Count.tsx
```typescript
import React from "react";
import { AppDispatch, RootState } from "../redux/store";
import { useSelector, useDispatch } from "react-redux";
import { fetchCount } from "../redux/countSlice";

let GLOBAL_COUNTER = 0;

const Count: React.FC = () => {
    const dispatch: AppDispatch = useDispatch();
    const { loading, item } = useSelector((state: RootState) => state.count);

    if (loading) return <div>Loading...</div>;

    const count = item.count;
    GLOBAL_COUNTER += count;

    return (
        <div>
            <h1>Count: {GLOBAL_COUNTER} (Fetched count: {count})</h1>
            <button onClick={() => dispatch(fetchCount())}>Increment</button>
        </div>
    );
}

export default Count;
```

* src/components/Data.tsx
```typescript
 import React from 'react';
 import Count from './Count';
 
 const Data: React.FC = () => {
     return (
         <div>
-            <h2>Data component.</h2>
+            <Count />
         </div>
     );
 };
 
 export default Data;
```

* src/index.tsx
```typescript
 import React from 'react';
 import ReactDOM from 'react-dom/client'
+import { Provider } from 'react-redux';
+import { store } from './redux/store';
 import App from './App';
 
 const root = ReactDOM.createRoot(document.getElementById('root') as HTMLElement);
 
 root.render(
-    <div>
+    <Provider store={store}>
         <App />
-    </div>
+    </Provider>
 );
```

```bash
$ npm start
```

# Redux 2 つ目

* src/redux/userListSlice.ts
```
import { createAsyncThunk, createSlice } from "@reduxjs/toolkit";

export const fetchUserList = createAsyncThunk('userList/fetchUserList', async () => {
    return [
        { id: 1, name: 'Taro Suzuki' },
        { id: 2, name: 'Hanako Tanaka' },
        { id: 3, name: 'Jiro Sato' }
    ];
});

interface User {
    id: number;
    name: string;
}

interface UserListState {
    loading: boolean;
    items: User[];
}

const initialState: UserListState = {
    loading: false,
    items: []
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
            });
    }
});

export default userListSlice.reducer;
```

* src/redux/store.ts
```typescript
 import { configureStore } from '@reduxjs/toolkit';
 import countReducer from './countSlice';
+import userListReducer from './userListSlice';
 
 export const store = configureStore({
     reducer: {
-        count: countReducer
+        count: countReducer,
+        userList: userListReducer
     }
 });
 
 export type RootState = ReturnType<typeof store.getState>;
 export type AppDispatch = typeof store.dispatch;
```

* src/components/Data.tsx
```typescript
 import React from 'react';
 import Count from './Count';
+import UserList from './UserList';
 
 const Data: React.FC = () => {
     return (
         <div>
             <Count />
+            <UserList />
         </div>
     );
 };
 
 export default Data;
```

* src/components/UserList.tsx
```typescript
import React, { useEffect } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { RootState, AppDispatch } from '../redux/store';
import { fetchUserList } from '../redux/userListSlice';

const UserList: React.FC = () => {
    const dispatch: AppDispatch = useDispatch();
    const { loading, items } = useSelector((state: RootState) => state.userList);

    if (loading) return <div>Loading users...</div>;

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
            <button onClick={() => dispatch(fetchUserList())}>Refresh User List</button>
        </div>
    );
};

export default UserList;
```



# Test server

```bash
$ npm install --save axios
```

* test_server.js
```javascript
const express = require('express');
const app = express();
const PORT = 18080;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function delayedResponse(res, body) {
  await sleep(1000);
  res.json(body);
}

// Middleware to parse JSON
app.use(express.json());

app.get('/', (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  numCount = Math.floor(Math.random() * 100 + 1);
  delayedResponse(res, {id: 1, count: numCount});
});

app.get('/userList', (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  numCount = Math.floor(Math.random() * 100 + 1);
  delayedResponse(
    res,
    [
      {id: 1, name: "Taro Suzuki"},
      {id: 2, name: "Hanako Tanaka"},
      {id: 3, name: "Jiro Sato"},
      {id: 4, name: "Saburo Yamada"},
      {id: 5, name: "Shiro Watanabe"}
    ]
  );
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
```

* src/redux/countSlice.tsx
```typescript
import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import axios from 'axios';

export const fetchCount = createAsyncThunk('items/fetchCount', async () => {
    const response = await axios.get('http://localhost:18080');
    return response.data;
})

interface CountObject {
    id: number;
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
```

* src/redux/userListSlice.tsx
```typescript
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
```

* ./src/components/Count.tsx
```typescript
import React from "react";
import { AppDispatch, RootState } from "../redux/store";
import { useSelector, useDispatch } from "react-redux";
import { fetchCount } from "../redux/countSlice";

let GLOBAL_COUNTER = 0;

const Count: React.FC = () => {
    const dispatch: AppDispatch = useDispatch();
    const { loading, item, error } = useSelector((state: RootState) => state.count);

    if (loading) return <div>Loading...</div>;
    if (error) return (
        <div>
            <h1>Error loading countes</h1>
            <button onClick={() => dispatch(fetchCount())}>Increment</button>
        </div>
    );

    const count = item.count;
    GLOBAL_COUNTER += count;

    return (
        <div>
            <h1>Count: {GLOBAL_COUNTER} (Fetched count: {count})</h1>
            <button onClick={() => dispatch(fetchCount())}>Increment</button>
        </div>
    );
}

export default Count;
```

* ./src/components/UserList.tsx
```typescript
import React, { useEffect } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { RootState, AppDispatch } from '../redux/store';
import { fetchUserList } from '../redux/userListSlice';

const UserList: React.FC = () => {
    const dispatch: AppDispatch = useDispatch();
    const { loading, items, error } = useSelector((state: RootState) => state.userList);

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
            <button onClick={() => dispatch(fetchUserList())}>Refresh User List</button>
        </div>
    );
};

export default UserList;
```

