// vim: set et ts=4 sw=4:
//
// Trivial libyui example.
//
// Compile with:
//
//     g++ -I/usr/include/yui -lyui test.cpp -o test
//
#include "YUI.h"
#include "YApplication.h"
#include "YWidgetFactory.h"
#include "YDialog.h"
#include "YPushButton.h"
#include "YLayoutBox.h"
#include "YReplacePoint.h"
#include "YEvent.h"
#include "YFrame.h"
#include <vector>

int main( int argc, char **argv )
{
   YUI::app()->setApplicationTitle("Test module");
   YUI::app()->setApplicationIcon("/usr/share/icons/mageia.png");

   YDialog    * dialog         = YUI::widgetFactory()->createPopupDialog();
   YFrame*      frame          = YUI::widgetFactory()->createFrame(dialog, "Test frame");
   YLayoutBox * hbox           = YUI::widgetFactory()->createHBox(frame);
   YFrame*      lframe         = YUI::widgetFactory()->createFrame(hbox, "Left frame");
   YFrame*      rframe         = YUI::widgetFactory()->createFrame(hbox, "Right frame");
   //  here we change the widget
   YReplacePoint* replacePoint = YUI::widgetFactory()->createReplacePoint(rframe);

   YLayoutBox * vbox_rframe    = YUI::widgetFactory()->createVBox( replacePoint );
   YLayoutBox * vbox   = YUI::widgetFactory()->createVBox( lframe );
//    vbox->setSize( 1000, 1000 );
   lframe->setWeight(YD_HORIZ, 25);
   rframe->setWeight(YD_HORIZ, 75);
   YUI::widgetFactory()->createLabel     ( vbox, "Hello, World!" );
   YPushButton* addButton   = YUI::widgetFactory()->createPushButton( vbox, "Add Button" );
   YPushButton* removeButton   = YUI::widgetFactory()->createPushButton( vbox, "Remove Button" );
   YPushButton* exitButton = YUI::widgetFactory()->createPushButton( vbox, "&Exit" );
   YUI::widgetFactory()->createSpacing( vbox, YD_VERT, true, 1.0 );

   //YPushButton* testButton = YUI::widgetFactory()->createPushButton( vbox, "&Cannot be added" );
   //testButton->hide();   <-- Angelo, I could not see this call in the api
   
   int bnum = 0;
   std::vector<YPushButton*>buttons;
   
   for (;;)
   {    
     YEvent* event = dialog->waitForEvent();
     // Check for window close
     if (event->eventType() == YEvent::CancelEvent)
     {
        break;
     }

     // Check for Exit button push
     if(event->widget() == (YWidget*)exitButton ) {
        break;
     };

     if(event->widget() == (YWidget*)addButton ) {
       if(bnum < 6) {
            dialog->startMultipleChanges();
            replacePoint->deleteChildren();
            vbox_rframe    = YUI::widgetFactory()->createVBox( replacePoint );
            bnum++;
            buttons.clear();
            for (int i=0; i < bnum; ++i) {                
               YPushButton* tmpB = YUI::widgetFactory()->createPushButton( vbox_rframe, "Delete Me" );
               buttons.push_back(tmpB);
            }
            replacePoint->showChild();
            dialog->recalcLayout();
            dialog->doneMultipleChanges();
       }
       else if (bnum == 6) {
            dialog->startMultipleChanges();
            replacePoint->deleteChildren();
            vbox_rframe    = YUI::widgetFactory()->createVBox( replacePoint );
            buttons.clear();
            for (int i=0; i < bnum; ++i) {                
               YPushButton* tmpB = YUI::widgetFactory()->createPushButton( vbox_rframe, "Delete Me" );
               buttons.push_back(tmpB);
            }
            YUI::widgetFactory()->createSpacing( vbox_rframe, YD_VERT, false, 1.0 );
            replacePoint->showChild();
            dialog->recalcLayout();
            dialog->doneMultipleChanges();
       }
     }
     if(event->widget() == (YWidget*)removeButton ) {
        if (bnum > 0) {
            dialog->startMultipleChanges();
            replacePoint->deleteChildren();
            vbox_rframe    = YUI::widgetFactory()->createVBox( replacePoint );
            bnum--;
            buttons.clear();
            for (int i=0; i < bnum; ++i) {                
                YPushButton* tmpB = YUI::widgetFactory()->createPushButton( vbox_rframe, "Delete Me" );
                buttons.push_back(tmpB);
            }
            replacePoint->showChild();
            dialog->recalcLayout();
            dialog->doneMultipleChanges();
        }
     }

     for(int i = 0; i < bnum; ++i) {
        if (event->widget() == (YWidget*)buttons[i]) {
            dialog->startMultipleChanges();
            replacePoint->deleteChildren();
            vbox_rframe    = YUI::widgetFactory()->createVBox( replacePoint );
            bnum--;
            buttons.clear();
            for (int i=0; i < bnum; ++i) {                
                YPushButton* tmpB = YUI::widgetFactory()->createPushButton( vbox_rframe, "Delete Me" );
                buttons.push_back(tmpB);
            }
            replacePoint->showChild();
            dialog->recalcLayout();
            dialog->doneMultipleChanges();
            break;
       }
     }
   }

   dialog->destroy();
}
