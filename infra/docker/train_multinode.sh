#!/usr/bin/env bash
NUM_GPU=${1:-1}
BATCH_SIZE_PER_GPU=${2:-1}
HOSTFILE=${3:-"hosts"}
THROUGHPUT_LOG_FREQ=${4:-2000}



echo ""
echo "NUM_GPU: ${NUM_GPU}"
echo "BATCH_SIZE_PER_GPU: ${BATCH_SIZE_PER_GPU}"
echo "THROUGHPUT_LOG_FREQ: ${THROUGHPUT_LOG_FREQ}"
echo ""

cd /mask-rcnn-tensorflow

mpirun -np ${NUM_GPU} \
--hostfile ${HOSTFILE} \
--allow-run-as-root \
--mca plm_rsh_no_tree_spawn 1 -bind-to none -map-by slot -mca pml ob1 \
-mca btl_vader_single_copy_mechanism none \
--mca btl tcp,self \
--mca btl_tcp_if_exclude lo,docker0 \
-x FI_PROVIDER="efa" \
-x FI_OFI_RXR_RX_COPY_UNEXP=1 \
-x FI_OFI_RXR_RX_COPY_OOO=1 \
-x FI_EFA_MR_CACHE_ENABLE=1 \
-x TF_CUDNN_USE_AUTOTUNE=0 \
-x TF_ENABLE_NHWC=1 \
-x FI_OFI_RXR_INLINE_MR_ENABLE=1 \
-x NCCL_TREE_THRESHOLD=4294967296 \
-x LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/efa/lib:/ofi/install/lib \
-x PATH \
-x NCCL_SOCKET_IFNAME=^docker0,lo \
-x NCCL_MIN_NRINGS=13 \
-x NCCL_DEBUG=INFO \
-x TENSORPACK_FP16=1 \
-x HOROVOD_CYCLE_TIME=0.5 \
-x HOROVOD_FUSION_THRESHOLD=67108864 \
--output-filename /logs/mpirun_logs \
/mask-rcnn-tensorflow/infra/docker/ompi_bind_p3dn.sh python3 /mask-rcnn-tensorflow/MaskRCNN/train.py \
--logdir /logs/train_log \
--fp16 \
--throughput_log_freq ${THROUGHPUT_LOG_FREQ} \
--config \
MODE_MASK=True \
MODE_FPN=True \
DATA.BASEDIR=/data \
DATA.TRAIN='["train2017"]' \
DATA.VAL='("val2017",)' \
TRAIN.BATCH_SIZE_PER_GPU=${BATCH_SIZE_PER_GPU} \
TRAIN.LR_EPOCH_SCHEDULE='[(9, 0.1), (12, 0.01), (20, None)]' \
TRAIN.EVAL_PERIOD=24 \
RPN.TOPK_PER_IMAGE=True \
PREPROC.PREDEFINED_PADDING=False \
BACKBONE.WEIGHTS=/data/pretrained-models/ImageNet-R50-AlignPadding.npz \
BACKBONE.NORM=FreezeBN \
TRAIN.BACKBONE_NCHW=False \
TRAIN.FPN_NCHW=False \
TRAIN.RPN_NCHW=False \
TRAIN.MASK_NCHW=False \
TRAIN.WARMUP_INIT_LR=0.000416666666667 \
FRCNN.BBOX_REG_WEIGHTS='[20., 20., 10., 10.]' \
TRAIN.GRADIENT_CLIP=1.5 \
RPN.SLOW_ACCURATE_MASK=False \
TRAINER=horovod
# You can set GRADIENT_CLIP to 0 to disable clip if your global batch size is smaller than 128
# To enable eval every epoch and early stop, add --async_eval after --fp16
