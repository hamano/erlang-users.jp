[これは何?]
一度出てきた用語を自動翻訳するためのsedスクリプトです。
単純な仕組みですが、以下のメリットがあります:
1.DRYを実現
2.用語の統一
他のコンテキストで出てこないような連続する単語や文字列
(environment variable、compiler、emulatorなど)は登録し
ても大丈夫かと思います。楽をするためにどんどん追記をお
願いします:D

[使い方]
sed -f sed/template.sed hoge.1

hoge.1:翻訳したいmanページ。
