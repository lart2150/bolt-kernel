#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>

static int __init hello_init(void)
{
	printk(KERN_INFO "tivo-kbuild: hello from a 3.14.28-1.16 out-of-tree module\n");
	return 0;
}
static void __exit hello_exit(void)
{
	printk(KERN_INFO "tivo-kbuild: goodbye\n");
}
module_init(hello_init);
module_exit(hello_exit);
MODULE_LICENSE("GPL");
MODULE_AUTHOR("bolt-re");
MODULE_DESCRIPTION("TiVo Bolt kernel build-env smoke test");
