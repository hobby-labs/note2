// After an instruction 11_README_WEBPACK.md
* [react,ts,redux,eslint,prettier,webpackな環境を一から作る](https://qiita.com/pokotyan/items/0521f6ea54ee801e53ad#lint%E3%81%AE%E7%92%B0%E5%A2%83%E3%82%92%E6%95%B4%E5%82%99)
* [Error in creating new React app using create-react-app appname](https://stackoverflow.com/a/79273240/4307818#)

```
$ npm i -D eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin
$ npm i -D prettier eslint-config-prettier
$ npx mrm lint-staged
```

ここでは、react, react-dom, @types/react, @types/react-dom は既にインストールされているため、ここでは行いません。

```
$ npm i -D eslint-plugin-react
```

* .eslintrc.js
```
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

ここで、動作確認を行います。

```
$ npm start
...
```

# typesync

```
$ npm i -D typesync
```

* package.json
```
{
  ...
  "scripts": {
    "preinstall": "typesync || :",
    ...
  }
  ...
}
```


