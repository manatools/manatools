#!/usr/bin/env python
# vim: set et ts=4 sw=4:
#coding:utf-8
#############################################################################
#
# contribfinder.py  -  Find Mageia Contributors informations
#
# License: GPLv3
# Author:  Matteo Pasotti, <matteo.pasotti@gmail.com>
#############################################################################

import sys
import os
from subprocess import check_output, STDOUT, call

###########
# imports #
###########
import yui
import locale


####################################
# LOCALE (important for TERMINAL!) #
####################################
# set the locale to de/utf-8
# locale.setlocale(locale.LC_ALL, "")
log = yui.YUILog.instance()
log.setLogFileName("debug.log")
log.enableDebugLogging( True )
appl = yui.YUI.application()
appl.setApplicationTitle("Contributor Finder")
# appl.setLanguage( "de", "UTF-8" )
#appl.setConsoleFont(magic, font, screenMap, unicodeMap, language)
# see /usr/share/YaST2/data/consolefonts.ycp
# appl.setConsoleFont("(K", "lat9w-16.psfu", "trivial", "", "en_US.UTF-8")


#################
# class mainGui #
#################
class mainGui():
    """
    Main class
    """

    def __init__(self):
        self.factory = yui.YUI.widgetFactory()
        self.dialog = self.factory.createPopupDialog()
        self.mainvbox = self.factory.createVBox(self.dialog)
        self.frameInput = self.factory.createFrame(self.mainvbox,"Package")
        self.inputHBox = self.factory.createHBox(self.frameInput)
        self.txtpkgname = self.factory.createInputField(self.inputHBox,"The name of the package")
        self.btnsearch = self.factory.createPushButton(self.inputHBox,"&Search")
        self.frameOutput = self.factory.createFrame(self.mainvbox,"Contributor")
        self.outputVBox = self.factory.createVBox(self.frameOutput)
        self.rtinformations = self.factory.createRichText(self.outputVBox,"")
        self.rtinformations.setWeight(yui.YD_HORIZ, 1)
        self.btnLookAtIt = self.factory.createPushButton(self.outputVBox,"&Show in browser")
        self.fourthhbox = self.factory.createHBox(self.mainvbox)
        self.closebutton = self.factory.createPushButton(self.factory.createRight(self.fourthhbox), "&Close")
        self.contributor = ''

    def stripErrMessages(self,output):
        items = output.split("\n")
        if(len(items)>1):
            result = items[1]
        else:
            result = output
        return result

    def invokeMgaRepo(self,pkgname):
        try:
            retoutput = check_output(['mgarepo','maintdb','get',pkgname],stderr=STDOUT)
        except:
            retoutput = "No contributors found"
        return retoutput

    def handleevent(self):
        """
        Event-handler for the 'widgets' demo
        """
        while True:
            event = self.dialog.waitForEvent()
            if event.eventType() == yui.YEvent.CancelEvent:
                self.dialog.destroy()
                break
            if event.widget() == self.closebutton:
                self.dialog.destroy()
                break
            if event.widget() == self.btnLookAtIt:
                if(cmp(self.contributor.strip(),"")!=0):
                  url = 'http://people.mageia.org/u/%s.html' % self.contributor
                  os.system("www-browser %s" % url)
            if event.widget() == self.btnsearch:
                #self.dialog.startMultipleChanges()
                #self.rtinformations.setValue("Loading...")
                #self.dialog.doneMultipleChanges()
                self.contributor = self.stripErrMessages(self.invokeMgaRepo(self.txtpkgname.value()))
                if(cmp(self.contributor.strip(),"")!=0):
                  outstr = 'Maintainer:&nbsp;<a href="http://people.mageia.org/u/%s.html">%s</a><br />e-mail:&nbsp;<a href="mailto:%s@mageia.org">%s@mageia.org</a>' % (self.contributor,self.contributor,self.contributor,self.contributor)
                else:
                  outstr = ''
                self.rtinformations.setValue(outstr)

if __name__ == "__main__":
    main_gui = mainGui()
    main_gui.handleevent()