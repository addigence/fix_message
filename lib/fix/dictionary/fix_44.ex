defmodule FIX.Dictionary.FIX44 do
  @moduledoc """
  The standard FIX data dictionary, and the parser's default.

  Covers every DATA/XMLDATA field in FIX 4.0-4.4, FIXT 1.1, and the FIX 5.0
  SecurityXML family (per the QuickFIX data dictionaries). For the full
  FIX 5.0 SP2 field set, use `FIX.Dictionary.FIX50SP2`. Custom user-defined
  data fields need their own dictionary:
  `use FIX.Dictionary, extends: FIX.Dictionary.FIX44`.

  The header and trailer tag sets are the union of the FIX 4.0-4.4 standard
  headers and trailers. They exclude the FIXT 1.1 session-layer tags
  (ApplVerID and friends) — use `FIX.Dictionary.FIX50SP2` for FIXT sessions.
  """
  use FIX.Dictionary

  # ----------------------------------------------------------------------------
  # Standard header
  # ----------------------------------------------------------------------------

  # BeginString
  header_field(8)
  # BodyLength
  header_field(9)
  # MsgType
  header_field(35)
  # SenderCompID
  header_field(49)
  # TargetCompID
  header_field(56)
  # OnBehalfOfCompID
  header_field(115)
  # DeliverToCompID
  header_field(128)
  # SecureDataLen
  header_field(90)
  # SecureData
  header_field(91)
  # MsgSeqNum
  header_field(34)
  # SenderSubID
  header_field(50)
  # SenderLocationID
  header_field(142)
  # TargetSubID
  header_field(57)
  # TargetLocationID
  header_field(143)
  # OnBehalfOfSubID
  header_field(116)
  # OnBehalfOfLocationID
  header_field(144)
  # DeliverToSubID
  header_field(129)
  # DeliverToLocationID
  header_field(145)
  # PossDupFlag
  header_field(43)
  # PossResend
  header_field(97)
  # SendingTime
  header_field(52)
  # OrigSendingTime
  header_field(122)
  # XmlDataLen
  header_field(212)
  # XmlData
  header_field(213)
  # MessageEncoding
  header_field(347)
  # LastMsgSeqNumProcessed
  header_field(369)
  # OnBehalfOfSendingTime (FIX 4.2/4.3 header; dropped in 4.4)
  header_field(370)
  # NoHops
  header_field(627)
  # HopCompID
  header_field(628)
  # HopSendingTime
  header_field(629)
  # HopRefID
  header_field(630)

  # ----------------------------------------------------------------------------
  # Standard trailer
  # ----------------------------------------------------------------------------

  # SignatureLength
  trailer_field(93)
  # Signature
  trailer_field(89)
  # CheckSum
  trailer_field(10)

  # ----------------------------------------------------------------------------
  # Data fields
  # ----------------------------------------------------------------------------

  # SecureDataLen -> SecureData
  data_field(90, 91)
  # SignatureLength -> Signature
  data_field(93, 89)
  # RawDataLength -> RawData
  data_field(95, 96)
  # XmlDataLen -> XmlData
  data_field(212, 213)
  # EncodedIssuerLen -> EncodedIssuer
  data_field(348, 349)
  # EncodedSecurityDescLen -> EncodedSecurityDesc
  data_field(350, 351)
  # EncodedListExecInstLen -> EncodedListExecInst
  data_field(352, 353)
  # EncodedTextLen -> EncodedText
  data_field(354, 355)
  # EncodedSubjectLen -> EncodedSubject
  data_field(356, 357)
  # EncodedHeadlineLen -> EncodedHeadline
  data_field(358, 359)
  # EncodedAllocTextLen -> EncodedAllocText
  data_field(360, 361)
  # EncodedUnderlyingIssuerLen -> EncodedUnderlyingIssuer
  data_field(362, 363)
  # EncodedUnderlyingSecurityDescLen -> EncodedUnderlyingSecurityDesc
  data_field(364, 365)
  # EncodedListStatusTextLen -> EncodedListStatusText
  data_field(445, 446)
  # EncodedLegIssuerLen -> EncodedLegIssuer
  data_field(618, 619)
  # EncodedLegSecurityDescLen -> EncodedLegSecurityDesc
  data_field(621, 622)
  # SecurityXMLLen -> SecurityXML
  data_field(1184, 1185)
  # DerivativeSecurityXMLLen -> DerivativeSecurityXML
  data_field(1282, 1283)
  # EncryptedPasswordLen -> EncryptedPassword
  data_field(1401, 1402)
  # EncryptedNewPasswordLen -> EncryptedNewPassword
  data_field(1403, 1404)
  # LegSecurityXMLLen -> LegSecurityXML
  data_field(1871, 1872)
  # UnderlyingSecurityXMLLen -> UnderlyingSecurityXML
  data_field(1874, 1875)
end
