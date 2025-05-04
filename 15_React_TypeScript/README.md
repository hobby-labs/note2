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
$ echo "node_modules" > .gitignore
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

type HomeProps = {
  name: string;
}

const Home: React.FC<HomeProps> = ({ name }) => {
    return (
        <div>
            <h1>{name} in component.</h1>
            This is a test page.
        </div>
    );
}

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
            <Home />
            <Data />
        </div>
    );
};

export default App;
```

