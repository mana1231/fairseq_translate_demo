### はじめに
- fairseq を uv 使って簡単に使うためだけのgit

### やって欲しいこと
- uv が使える環境であること
- fairseq の git clone 
~~~
git clone https://github.com/pytorch/fairseq
~~~
- コードの修正
  - fairseq/setup.py
  - 187     "torch>=1.13",  ->  "torch>=1.11",

その後 uv sync
