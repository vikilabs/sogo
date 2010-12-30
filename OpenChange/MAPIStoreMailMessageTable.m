/* MAPIStoreMailMessageTable.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>

#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/NSArray+Utilities.h>

#import <Mailer/SOGoMailFolder.h>
#import <Mailer/SOGoMailObject.h>

#import "MAPIStoreContext.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSCalendarDate+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreMailMessageTable.h"

#include <libmapi/mapidefs.h>
#include <mapistore/mapistore_nameid.h>

@implementation MAPIStoreMailMessageTable

static Class NSDataK, NSStringK;

+ (void) initialize
{
  NSDataK = [NSData class];
  NSStringK = [NSString class];
}

- (NSArray *) childKeys
{
  return [folder toOneRelationshipKeys];
}

- (NSArray *) restrictedChildKeys
{
  NSArray *keys;
  
  if (restrictionState == MAPIRestrictionStateAlwaysTrue)
    keys = [self cachedChildKeys];
  else if (restrictionState == MAPIRestrictionStateAlwaysFalse)
    keys = [NSArray array];
  else
    {
      keys = [[folder fetchUIDsMatchingQualifier: restriction
		      sortOrdering: @"ARRIVAL"]
	       stringsWithFormat: @"%@.eml"];
      [self logWithFormat: @"  restricted keys: %@", keys];
    }

  return keys;
}

- (enum MAPISTATUS) getChildProperty: (void **) data
			      forKey: (NSString *) childKey
			     withTag: (enum MAPITAGS) propTag
{
  SOGoMailObject *child;
  NSString *childURL, *stringValue;
  enum MAPISTATUS rc;

  rc = MAPI_E_SUCCESS;
  switch (propTag)
    {
    case PR_ICON_INDEX: // TODO
      /* read mail, see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
      *data = MAPILongValue (memCtx, 0x00000100);
      break;
    case PR_CONVERSATION_TOPIC:
    case PR_CONVERSATION_TOPIC_UNICODE:
    case PR_SUBJECT:
    case PR_SUBJECT_UNICODE:
      child = [self lookupChild: childKey];
      stringValue = [child decodedSubject];
      if (!stringValue)
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_MESSAGE_CLASS_UNICODE:
    case PR_ORIG_MESSAGE_CLASS_UNICODE:
      *data = talloc_strdup (memCtx, "IPM.Note");
      break;
    case PidLidRemoteAttachment: // TODO
    case PR_HASATTACH: // TODO
    case PR_REPLY_REQUESTED: // TODO
    case PR_RESPONSE_REQUESTED: // TODO
      *data = MAPIBoolValue (memCtx, NO);
      break;
    // case PidLidHeaderItem:
    //   *data = MAPILongValue (memCtx, 0x00000001);
    //   break;
    // case PidLidRemoteTransferSize:
    //   rc = [self getChildProperty: data
    // 			   forKey: childKey
    // 			  withTag: PR_MESSAGE_SIZE];
    //   break;
    case PR_CREATION_TIME: // DOUBT
    case PR_LAST_MODIFICATION_TIME: // DOUBT
    case PR_LATEST_DELIVERY_TIME: // DOUBT
    case PR_ORIGINAL_SUBMIT_TIME:
    case PR_CLIENT_SUBMIT_TIME:
    case PR_MESSAGE_DELIVERY_TIME:
      child = [self lookupChild: childKey];
      // offsetDate = [[child date] addYear: -1 month: 0 day: 0
      //                               hour: 0 minute: 0 second: 0];
      // *data = [offsetDate asFileTimeInMemCtx: memCtx];
      *data = [[child date] asFileTimeInMemCtx: memCtx];
      break;
    case PR_MESSAGE_FLAGS: // TODO
      // NSDictionary *coreInfos;
      // NSArray *flags;
      // child = [self lookupChild: childKey];
      // coreInfos = [child fetchCoreInfos];
      // flags = [coreInfos objectForKey: @"flags"];
      *data = MAPILongValue (memCtx, 0x02 | 0x20); // fromme + unmodified
      break;

    case PR_FLAG_STATUS: // TODO
    case PR_SENSITIVITY: // TODO
    case PR_ORIGINAL_SENSITIVITY: // TODO
    case PR_FOLLOWUP_ICON: // TODO
      *data = MAPILongValue (memCtx, 0);
      break;

    case PR_EXPIRY_TIME: // TODO
    case PR_REPLY_TIME:
      *data = [[NSCalendarDate date] asFileTimeInMemCtx: memCtx];
      break;

    case PR_SENT_REPRESENTING_ADDRTYPE_UNICODE:
      *data = [@"SMTP" asUnicodeInMemCtx: memCtx];
      break;
    case PR_SENT_REPRESENTING_EMAIL_ADDRESS_UNICODE:
    case PR_SENT_REPRESENTING_NAME_UNICODE:
      child = [self lookupChild: childKey];
      *data = [[child from] asUnicodeInMemCtx: memCtx];
      break;

      /* TODO: the following are supposed to be display names, separated by a semicolumn */
    case PR_RECEIVED_BY_NAME:
    case PR_DISPLAY_TO:
    case PR_DISPLAY_TO_UNICODE:
    case PR_ORIGINAL_DISPLAY_TO_UNICODE:
      child = [self lookupChild: childKey];
      stringValue = [child to];
      if (!stringValue)
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_DISPLAY_CC:
    case PR_DISPLAY_CC_UNICODE:
    case PR_ORIGINAL_DISPLAY_CC_UNICODE:
      child = [self lookupChild: childKey];
      stringValue = [child cc];
      if (!stringValue)
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_DISPLAY_BCC:
    case PR_DISPLAY_BCC_UNICODE:
    case PR_ORIGINAL_DISPLAY_BCC_UNICODE:
      stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PidNameContentType:
      *data = [@"message/rfc822" asUnicodeInMemCtx: memCtx];
      break;

    case PR_BODY:
    case PR_BODY_UNICODE:
      {
        NSMutableArray *keys;
        NSArray *acceptedTypes;

        child = [self lookupChild: childKey];

        acceptedTypes = [NSArray arrayWithObjects: @"text/plain",
                                 @"text/html", nil];
        keys = [NSMutableArray array];
        [child addRequiredKeysOfStructure: [child bodyStructure]
                                     path: @"" toArray: keys
                            acceptedTypes: acceptedTypes];
        if ([keys count] == 0 || [keys count] == 2)
          {
            *data = NULL;
            rc = MAPI_E_NOT_FOUND;
          }
        else
          {
            acceptedTypes = [NSArray arrayWithObject: @"text/plain"];
            [keys removeAllObjects];
            [child addRequiredKeysOfStructure: [child bodyStructure]
                                         path: @"" toArray: keys
                                acceptedTypes: acceptedTypes];
            if ([keys count] > 0)
              {
                id result;
                NSData *content;
                NSString *key;
                
                result = [child fetchParts: [keys objectsForKey: @"key"
                                                 notFoundMarker: nil]];
                result = [[result valueForKey: @"RawResponse"] objectForKey: @"fetch"];
                key = [[keys objectAtIndex: 0] objectForKey: @"key"];
                content = [[result objectForKey: key] objectForKey: @"data"];
		if ([content length] > 3999)
		  {
		    childURL = [NSString stringWithFormat: @"%@%@", folderURL, childKey];
		    [context registerValue: content
				asProperty: propTag
				    forURL: childURL];
		    *data = NULL;
		    rc = MAPI_E_NOT_ENOUGH_MEMORY;
		  }
		else
		  {
		    stringValue = [[NSString alloc] initWithData: content
							  encoding: NSISOLatin1StringEncoding];
		    *data = [stringValue asUnicodeInMemCtx: memCtx];
		  }
              }
            else
	      rc = MAPI_E_NOT_FOUND;
          }
      }
      break;
      
    case PR_HTML:
      {
        NSMutableArray *keys;
        NSArray *acceptedTypes;

        child = [self lookupChild: childKey];
        
        acceptedTypes = [NSArray arrayWithObject: @"text/html"];
        keys = [NSMutableArray array];
        [child addRequiredKeysOfStructure: [child bodyStructure]
                                    path: @"" toArray: keys acceptedTypes: acceptedTypes];
        if ([keys count] > 0)
          {
            id result;
            NSString *key;
            NSData *content;
            
            result = [child fetchParts: [keys objectsForKey: @"key"
                                            notFoundMarker: nil]];
            result = [[result valueForKey: @"RawResponse"] objectForKey:
                                            @"fetch"];
            key = [[keys objectAtIndex: 0] objectForKey: @"key"];
            content = [[result objectForKey: key] objectForKey: @"data"];
	    if ([content length] > 3999)
	      {
		childURL = [NSString stringWithFormat: @"%@%@", folderURL, childKey];
		[context registerValue: content
			    asProperty: propTag
				forURL: childURL];
		*data = NULL;
		rc = MAPI_E_NOT_ENOUGH_MEMORY;
	      }
	    else
	      *data = [content asBinaryInMemCtx: memCtx];
          }
        else
          {
            *data = NULL;
            rc = MAPI_E_NOT_FOUND;
          }
      }
      break;

      /* We don't handle any RTF content. */
    case PR_RTF_COMPRESSED:
      rc = MAPI_E_NOT_FOUND;
      break;
    case PR_RTF_IN_SYNC:
      *data = MAPIBoolValue (memCtx, NO);
      break;
    case PR_INTERNET_MESSAGE_ID:
    case PR_INTERNET_MESSAGE_ID_UNICODE:
      child = [self lookupChild: childKey];
      *data = [[child messageId] asUnicodeInMemCtx: memCtx];
      break;
    case PR_READ_RECEIPT_REQUESTED: // TODO
      *data = MAPIBoolValue (memCtx, NO);
      break;
    case PidLidPrivate:
      *data = MAPIBoolValue (memCtx, NO);
      break;
    case PidLidImapDeleted:
      *data = MAPILongValue (memCtx, 0);
      break;

    case PR_MSG_EDITOR_FORMAT:
      {
        NSMutableArray *keys;
        NSArray *acceptedTypes;
        uint32_t format;

        child = [self lookupChild: childKey];

        format = 0; /* EDITOR_FORMAT_DONTKNOW */

        acceptedTypes = [NSArray arrayWithObject: @"text/plain"];
        keys = [NSMutableArray array];
        [child addRequiredKeysOfStructure: [child bodyStructure]
                                     path: @"" toArray: keys
                            acceptedTypes: acceptedTypes];
        if ([keys count] == 1)
          format = EDITOR_FORMAT_PLAINTEXT;

        acceptedTypes = [NSArray arrayWithObject: @"text/html"];
        [keys removeAllObjects];
        [child addRequiredKeysOfStructure: [child bodyStructure]
                                     path: @"" toArray: keys
                            acceptedTypes: acceptedTypes];
        if ([keys count] == 1)
          format = EDITOR_FORMAT_HTML;

        *data = MAPILongValue (memCtx, format);
      }
      break;

    case PidLidReminderSet: // TODO
    case PidLidUseTnef: // TODO
      *data = MAPIBoolValue (memCtx, NO);
      break;
    case PidLidRemoteStatus: // TODO
      *data = MAPILongValue (memCtx, 0);
      break;
    case PidLidSmartNoAttach: // TODO
    case PidLidAgingDontAgeMe: // TODO
      *data = MAPIBoolValue (memCtx, YES);
      break;

// PidLidFlagRequest
// PidLidBillingInformation
// PidLidMileage
// PidLidCommonEnd
// PidLidCommonStart
// PidLidNonSendableBcc
// PidLidNonSendableCc
// PidLidNonSendtableTo
// PidLidNonSendBccTrackStatus
// PidLidNonSendCcTrackStatus
// PidLidNonSendToTrackStatus
// PidLidReminderDelta
// PidLidReminderFileParameter
// PidLidReminderSignalTime
// PidLidReminderOverride
// PidLidReminderPlaySound
// PidLidReminderTime
// PidLidReminderType
// PidLidSmartNoAttach
// PidLidTaskGlobalId
// PidLidTaskMode
// PidLidVerbResponse
// PidLidVerbStream
// PidLidInternetAccountName
// PidLidInternetAccountStamp
// PidLidContactLinkName
// PidLidContactLinkEntry
// PidLidContactLinkSearchKey
// PidLidSpamOriginalFolder

    default:
      rc = [super getChildProperty: data
			    forKey: childKey
			   withTag: propTag];
    }

  return rc;
}


- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  static NSMutableDictionary *knownProperties = nil;

  if (!knownProperties)
    {
      knownProperties = [NSMutableDictionary new];
      [knownProperties setObject: @"DATE"
			  forKey: MAPIPropertyKey (PR_CLIENT_SUBMIT_TIME)];
      [knownProperties setObject: @"DATE"
			  forKey: MAPIPropertyKey (PR_MESSAGE_DELIVERY_TIME)];
      [knownProperties setObject: @"MESSAGE-ID"
			  forKey: MAPIPropertyKey (PR_INTERNET_MESSAGE_ID_UNICODE)];
    }

  return [knownProperties objectForKey: MAPIPropertyKey (property)];
}

/* restrictions */

- (void) setRestrictions: (const struct mapi_SRestriction *) res
{
  [super setRestrictions: res];
}

- (MAPIRestrictionState) evaluatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;
  id value;

  value = NSObjectFromMAPISPropValue (&res->lpProp);
  switch (res->ulPropTag)
    {
    case PR_MESSAGE_CLASS_UNICODE:
      if ([value isEqualToString: @"IPM.Note"])
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
      break;

    case PidLidAppointmentStartWhole:
    case PidLidAppointmentEndWhole:
    case PidLidRecurring:
      [self logWithFormat: @"apt restriction on mail folder?"];
      rc = MAPIRestrictionStateAlwaysFalse;
      break;

    case PidLidAutoProcessState:
      if ([value intValue] == 0)
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
      break;

    case PR_SEARCH_KEY:
      rc = MAPIRestrictionStateAlwaysFalse;
      break;

    case 0x0fff00fb: /* PR_ENTRY_ID in PtyServerId form */
    case 0x0ff600fb:
      /*                                 resProperty: struct mapi_SPropertyRestriction
                                    relop                    : 0x04 (4)
                                    ulPropTag                : UNKNOWN_ENUM_VALUE (0xFF600FB)
                                    lpProp: struct mapi_SPropValue
                                        ulPropTag                : UNKNOWN_ENUM_VALUE (0xFF600FB)
                                        value                    : union mapi_SPropValue_CTR(case 251)
                                        bin                      : SBinary_short cb=21
[0000] 01 01 00 1A 00 00 00 00   00 9C 83 E8 0F 00 00 00   ........ ........
[0010] 00 00 00 00 00                                    ..... */
	rc = MAPIRestrictionStateAlwaysFalse;
      break;

    case PR_CONVERSATION_KEY:
	rc = MAPIRestrictionStateAlwaysFalse;
      break;
      
    default:
      rc = [super evaluatePropertyRestriction: res intoQualifier: qualifier];
    }

  return rc;
}

- (MAPIRestrictionState) evaluateContentRestriction: (struct mapi_SContentRestriction *) res
				      intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;
  id value;

  value = NSObjectFromMAPISPropValue (&res->lpProp);
  if ([value isKindOfClass: NSDataK])
    {
      value = [[NSString alloc] initWithData: value
				    encoding: NSUTF8StringEncoding];
      [value autorelease];
    }
  else if (![value isKindOfClass: NSStringK])
    [NSException raise: @"MAPIStoreTypeConversionException"
		format: @"unhandled content restriction for class '%@'",
		 NSStringFromClass ([value class])];

  switch (res->ulPropTag)
    {
    case PR_MESSAGE_CLASS_UNICODE:
      if ([value isEqualToString: @"IPM.Note"])
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
      break;
    case PR_CONVERSATION_KEY:
      rc = MAPIRestrictionStateAlwaysFalse;
      break;
    default:
      rc = [super evaluateContentRestriction: res intoQualifier: qualifier];
    }

  return rc;
}

- (MAPIRestrictionState) evaluateExistRestriction: (struct mapi_SExistRestriction *) res
				    intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;

  switch (res->ulPropTag)
    {
    case PR_MESSAGE_CLASS_UNICODE:
      rc = MAPIRestrictionStateAlwaysFalse;
      break;
    case PR_MESSAGE_DELIVERY_TIME:
      rc = MAPIRestrictionStateAlwaysTrue;
      break;
    case PR_PROCESSED:
      rc = MAPIRestrictionStateAlwaysFalse;
      break;
    default:
      rc = [super evaluateExistRestriction: res intoQualifier: qualifier];
    }

  return rc;
}

@end
