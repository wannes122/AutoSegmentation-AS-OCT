# AutoSegmentation-AS-OCT
Automatic cornea &amp; lens segmentation in noisy AS-OCT B-scans using U-Net (EfficientNet-B2), robust boundary fitting, and biometry extraction.


This repo contains a deep-learning pipeline for automatic segmentation of the cornea and crystalline lens in noisy anterior-segment OCT (AS-OCT) B-scans of rabbit eyes. Images are preprocessed with residual-driven NL-means denoising, segmented with a U-Net + ImageNet-pretrained EfficientNet-B2 encoder, and converted to smooth anatomical interfaces via RANSAC-regularized cubic fits. The workflow delivers high IoU on cornea and lens, generalizes to an independent test set, and outperforms a classical graph-search baseline. Includes training, evaluation, boundary extraction, and visualization scripts.

This repo also contains the developed MATLAB code used to make the labled data starting from the collected OCT images. 
