# Create new project

```bash
$ mkdir react-ts
$ cd react-ts
$ npm init -y
$ ls -l
> ... package.json
```

```
$ npm install --save react react-dom
$ npm install --save-dev typescript @types/react @types/react-dom
$ npm install --save-dev webpack webpack-cli webpack-dev-server ts-loader
$ npm install --save-dev @babel/core @babel/preset-env @babel/preset-react @babel/preset-typescript babel-loader
```

Create a `webpack.config.js`.

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

Setup babel.

```
$ npm install --save-dev @babel/core babel-loader @babel/preset-env @babel/preset-react @babel/preset-typescript
```

Create `.babelrc` file.

* .babelrc
```
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

Update `webpack.config.js` to include babel-loader.

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

Create `./src/index.html`.

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

* webpack.config.js
```javascript
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
   }
-  };
+  },
+  plugins: [
+      new HtmlWebpackPlugin({
+        template: './src/index.html'
+      })
+    ]
+  };
```

`html-webpack-plugin` は、JavaScript が組み込まれたHTML を`dist` ディレクトリに作成します。
複数のJavaScript ファイルを組み込み、HTML ファイルとして提供することを自動化します。

# TypeScript React Component  の例

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

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
```

# プロジェクトの起動

* package.json(一部抜粋)
```json
{
  "scripts": {
    "start": "webpack serve --open --mode development",
    "build": "webpack --mode production"
  }
}
```

`production` オプションで、production モードでビルドします。
これは、資材の縮小化や無駄なコードの削除を行い、商用環境へ向けた最適化されたビルドを生成します。

```bash
$ npm start
## visit http://localhost:8080
```


# Reference
- [Building a TypeScript-React Project from Scratch with Webpack](https://medium.com/javascript-journal-unlocking-project-potential/building-a-typescript-react-project-from-scratch-with-webpack-b224a3f84e3b)
- [Webpackを一歩一歩確実に理解してReact + TypeScript環境を作る](https://qiita.com/Mr_ozin/items/b6749e60b185a26b97f0)
- [Creating a React App - React](https://react.dev/learn/creating-a-react-app#production-grade-react-frameworks)
- [Using TypeScript - React](https://react.dev/learn/typescript)


