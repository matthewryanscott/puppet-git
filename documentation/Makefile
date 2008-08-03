#Makefile for documentation

XML_LANG	= en-US
DOC_TYPE		= Article
DOCNAME		= documentation
PRODUCT	= Documentation
#BRAND		= fedora

#OTHER_LANGS	= as-IN bn-IN de-DE es-ES fr-FR gu-IN hi-IN it-IT ja-JP kn-IN ko-KR ml-IN mr-IN or-IN pa-IN pt-BR ru-RU si-LK ta-IN te-IN zh-CN zh-TW
TRANSLATIONS	= $(XML_LANG) $(OTHER_LANGS)

COMMON_CONFIG  = /usr/share/publican
include $(COMMON_CONFIG)/make/Makefile.common

release: html
	@rsync -aHvz --delete --rsh=ssh tmp/en-US/html/ puppetmanaged.org:/data/www/puppetmanaged.org/www/public_html/documentation/git-module/

