项目文档见：https://docs.geedge.net/pages/viewpage.action?pageId=143941807

这个仓库分支关系如下：
* master：这个仓库最早的分支，克隆自 github-onie
* master → GN-2021.06-dev(rel-21.07与之同步) →  dev-23.06(rel-23.06落后dev-23.06) 
* master → onie-offical(在master的基础上, 更新了onie) →  dev-24.12

不同分支相对于onie的修改目的：(这个得逐个commit往前看了，比较复杂。这里只看最后的输出文件)
* dev-23.06分支，为三种设备提供onie：7400-MCN-P01R01、9000-NPB-P01R01、TSG-X_NXR620G40_R01
* dev-24.12分支，为两种比较通用的设备提供onie：x86_64_COTS、AArch64_COTS。
