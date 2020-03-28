#!/usr/bin/env python3
# vim: set et ts=4 sw=4:
#coding:utf-8
#############################################################################
#
# contribfinder.py  -  Find Mageia Contributors information
# A trivial python script that queries the maintainers database.
# The GUI uses libyui thus contribfinder is able to 
# comfortably behave like a native gtk or qt5 or ncurses application :-)
#
# License: GPLv3
# Author:  Matteo Pasotti, <matteo.pasotti@gmail.com>
#############################################################################

import sys
import os
import httplib2

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

    def queryMaintDB(self,pkgname):
        try:
            dlurl = 'http://maintdb.mageia.org/' + pkgname
            h = httplib2.Http()
            resp, content = h.request(dlurl, 'GET')
            if resp.status != 200:
                raise Exception('Package cannot be found in maintdb')
            str_content = content.decode('utf-8')
            retoutput = str_content.rstrip('\n')
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
                if(self.contributor.strip()):
                  url = 'http://people.mageia.org/u/%s.html' % self.contributor
                  os.system("www-browser %s" % url)
            if event.widget() == self.btnsearch:
                #self.dialog.startMultipleChanges()
                #self.rtinformations.setValue("Loading...")
                #self.dialog.doneMultipleChanges()
                self.contributor = self.stripErrMessages(self.queryMaintDB(self.txtpkgname.value()))
                if(self.contributor.strip()):
                  outstr = 'Maintainer:&nbsp;<a href="http://people.mageia.org/u/%s.html">%s</a><br />e-mail:&nbsp;<a href="mailto:%s@mageia.org">%s@mageia.org</a>' % (self.contributor,self.contributor,self.contributor,self.contributor)
                else:
                  outstr = ''
                self.rtinformations.setValue(outstr)

if __name__ == "__main__":
    main_gui = mainGui()
    main_gui.handleevent()
