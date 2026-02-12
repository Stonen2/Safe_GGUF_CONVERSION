docker run --rm -it `
  --cpus="0" `
  --memory=32g `
  --memory-swap=32g `
  -e CUDA_VISIBLE_DEVICES="" `
  -e OMP_NUM_THREADS=0 `
  -e MKL_NUM_THREADS=0 `
  -v "C:\Users\ISAdmin\Desktop\LLM\llama.cpp:/workspace/llama.cpp" `
  -v "D:\models\org-model:/workspace/input" `
  -v "D:\models\output:/workspace/output" `
  pytorch/pytorch `
  bash
