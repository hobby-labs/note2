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
$ npm install --save-dev prettier eslint-config-prettier
$ git init --initial-branch=main
$ npx mrm lint-staged
```

* .eslintrc.js
```javascript
module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  parser: '@typescript-eslint/parser',
  parserOptions: {
    sourceType: 'module',
    ecmaVersion: 2019,
    tsconfigRootDir: __dirname,
    project: ['./tsconfig.eslint.json'],
  },
  plugins: ['@typescript-eslint'],
  extends: [
    'eslint:recommended',
    'plugin:react/recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:@typescript-eslint/recommended-requiring-type-checking',
    'prettier',
    'prettier/@typescript-eslint',
    'prettier/react',
  ],
  rules: {},
};
```

```bash
$ npm i -D eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin
$ npm i -D prettier eslint-config-prettier
$ npx mrm lint-staged
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

* package.json(一部抜粋)
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

const App: React.FC = () => {
    return (
        <div>
            <h1>Hello, React!</h1>
        </div>
    );
};

const root = ReactDOM.createRoot(document.getElementById('root') as HTMLElement);
root.render(<App />);
```

* package.json(一部抜粋)
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


