#!/bin/bash
DATA=$BASE/data_base/kftt-data-1.0/data
DATABIN=$BASE/data_bin
SRC=ja
TGT=en
MODEL_SAVE=$BASE/model_save
ARCH=transformer
CURRENT_TIME=$(date +%m%d%H%M)
dt_start=$( date +"%s%3N" )

### preprocess datas by spm
echo 'spm'
uv run spm_train \
    --input=$DATA/orig/kyoto-train.$SRC,$DATA/orig/kyoto-train.$TGT \
    --model_prefix=$DATA/spm --vocab_size=32000 --character_coverage=0.9995 --model_type=bpe

mkdir -p $DATA/spm_tok
for split in train dev test; do
    for lang in $SRC $TGT; do
        uv run spm_encode --model=$DATA/spm.model --output_format=piece \
            --input=$DATA/orig/kyoto-${split}.${lang} \
            --output=$DATA/spm_tok/kyoto-${split}.spm.${lang}
    done
done
echo 'done'

echo 'preprocess'
uv run fairseq-preprocess \
    --source-lang $SRC --target-lang $TGT \
    --trainpref $DATA/spm_tok/kyoto-train.spm \
    --validpref $DATA/spm_tok/kyoto-dev.spm \
    --testpref $DATA/spm_tok/kyoto-test.spm \
    --destdir $DATABIN \
    --workers 4
echo 'done'

### train transformer
# you need to edit some parameters.
mkdir -p $MODEL_SAVE
echo 'train start.'
uv run fairseq-train $DATABIN \
    --arch $ARCH \
    --optimizer adam --lr 0.0001 \
    --lr-scheduler inverse_sqrt --warmup-updates 4000 \
    --clip-norm 0.1 \
    --dropout 0.3 \
    --max-tokens 4096 \
    --patience 20 \
    --max-epoch 2 \
    --fp16 \
    --save-dir ${MODEL_SAVE}/${ARCH}_${SRC}_${TGT}
echo 'done'

### translate
uv run fairseq-generate $DATABIN \
    --path ${MODEL_SAVE}/${ARCH}_${SRC}_${TGT}/checkpoint_best.pt \
    --beam 5 --source-lang $SRC --target-lang $TGT \
    --gen-subset test > $DATA/test-output

cat $DATA/test-output | grep -P "^H" |sort -V |cut -f 3- | sed 's/\[en_XX\]//g' > $DATA/test-output.pred
cat $DATA/test-output | grep -P "^T" |sort -V |cut -f 2- | sed 's/\[en_XX\]//g' > $DATA/test-output.ref

dt_end=$( date +"%s%3N" )
elapsed=$(( dt_end - dt_start ))
echo "実行時間:" ${elapsed} "[ms]"