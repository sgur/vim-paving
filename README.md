vim-paving
==========

Yet Another なプラグインローダーの技術検証です。

とりあえず Pure Vim script です。

特徴
----

`:Pave` コマンドによりプラグインローダー Vim script (標準では `~/.vimrc.paved`) を生成します。

起動時は、そのファイルを `source` することにより、`runtimepath` 等の設定や ftdetect のロードを行います。

使い方
-----

### コマンド

~~~vim
:Pave [-bundle[=~/.vim/bundle]] [-ftbundle[=~/.vim/ftbundle]] [~/.vimrc.paved]
~~~

デフォルト設定もしくは `g:paving#config` の設定をもとにプラグインローダーを生成します。
`:
### コマンド引数

- -bundle
- -ftbundle

~~~vim
:Pave -bundle -ftbundle ~/.vimrc.loader
~~~

~~~vim
:Pave -bundle=~/.vim/bundler,~/.vim/local -ftbundle=~/.vim/filetype ~/.vimrc.loader
~~~

Requirements
------------

Vim 7.4

インストール方法と初回起動
------------

1. `~/.vim` もしくは `~/vimfiles` に放り込む。(`~/.vim/bundle` 以下への配置を推奨)
2. Vim を起動して、`:source path/to/plugin/paving.vim`
3. `:Pave` でローダーを生成

License
-------

MIT License
