defmodule FIX.Dictionary.FIX44 do
  @moduledoc """
  The standard FIX data dictionary, and the parser's default.

  Covers every DATA/XMLDATA field in FIX 4.0-4.4, FIXT 1.1, and the FIX 5.0
  SecurityXML family (per the QuickFIX data dictionaries). For the full
  FIX 5.0 SP2 field set, use `FIX.Dictionary.FIX50SP2`. Custom user-defined
  data fields need their own dictionary:
  `use FIX.Dictionary, extends: FIX.Dictionary.FIX44`.
  """
  use FIX.Dictionary

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
