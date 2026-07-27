defmodule FIX.Dictionary.FIX50SP2 do
  @moduledoc """
  The complete FIX 5.0 SP2 data dictionary.

  Covers every DATA/XMLDATA field in FIX 5.0 SP2 (including its extension
  packs) plus the FIXT 1.1 session-layer data fields — 83 pairs in total,
  extracted from the QuickFIX `FIX50SP2.xml`/`FIXT11.xml` data dictionaries
  (see `bench/extract_sp2_pairs.exs`). This is a superset of
  `FIX.Dictionary.FIX44`.

  Note the irregular pairings, which is why this table is generated rather
  than inferred: most companions are adjacent (`len + 1 = data`), but some
  have gaps (1525 -> 1527, 1678 -> 1697), some are reverse-ordered
  (2372 -> 2371, 2802 -> 2801), and the PaymentStreamFormula XMLDATA fields
  are far from their length fields (43109 -> 42684).
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
  # DerivativeEncodedIssuerLen -> DerivativeEncodedIssuer
  data_field(1277, 1278)
  # DerivativeEncodedSecurityDescLen -> DerivativeEncodedSecurityDesc
  data_field(1280, 1281)
  # DerivativeSecurityXMLLen -> DerivativeSecurityXML
  data_field(1282, 1283)
  # EncodedMktSegmDescLen -> EncodedMktSegmDesc
  data_field(1397, 1398)
  # EncryptedPasswordLen -> EncryptedPassword
  data_field(1401, 1402)
  # EncryptedNewPasswordLen -> EncryptedNewPassword
  data_field(1403, 1404)
  # EncodedSecurityListDescLen -> EncodedSecurityListDesc
  data_field(1468, 1469)
  # EncodedDocumentationTextLen -> EncodedDocumentationText
  data_field(1525, 1527)
  # EncodedEventTextLen -> EncodedEventText
  data_field(1578, 1579)
  # InstrumentScopeEncodedSecurityDescLen -> InstrumentScopeEncodedSecurityDesc
  data_field(1620, 1621)
  # EncodedRejectTextLen -> EncodedRejectText
  data_field(1664, 1665)
  # EncodedOptionExpirationDescLen -> EncodedOptionExpirationDesc
  data_field(1678, 1697)
  # EncodedFirmAllocTextLen -> EncodedFirmAllocText
  data_field(1733, 1734)
  # LegSecurityXMLLen -> LegSecurityXML
  data_field(1871, 1872)
  # UnderlyingSecurityXMLLen -> UnderlyingSecurityXML
  data_field(1874, 1875)
  # EncodedUnderlyingEventTextLen -> EncodedUnderlyingEventText
  data_field(2072, 2073)
  # EncodedLegEventTextLen -> EncodedLegEventText
  data_field(2074, 2075)
  # EncodedAttachmentLen -> EncodedAttachment
  data_field(2111, 2112)
  # EncodedLegOptionExpirationDescLen -> EncodedLegOptionExpirationDesc
  data_field(2179, 2180)
  # EncodedUnderlyingOptionExpirationDescLen -> EncodedUnderlyingOptionExpirationDesc
  data_field(2287, 2288)
  # EncodedComplianceTextLen -> EncodedComplianceText
  data_field(2351, 2352)
  # EncodedTradeContinuationTextLen -> EncodedTradeContinuationText
  data_field(2372, 2371)
  # EncodedMDStatisticDescLen -> EncodedMDStatisticDesc
  data_field(2481, 2482)
  # EncodedLegDocumentationTextLen -> EncodedLegDocumentationText
  data_field(2494, 2493)
  # EncodedWarningTextLen -> EncodedWarningText
  data_field(2522, 2521)
  # EncodedMiscFeeSubTypeDescLen -> EncodedMiscFeeSubTypeDesc
  data_field(2637, 2638)
  # EncodedCommissionDescLen -> EncodedCommissionDesc
  data_field(2651, 2652)
  # EncodedAllocCommissionDescLen -> EncodedAllocCommissionDesc
  data_field(2665, 2666)
  # EncodedFinancialInstrumentFullNameLen -> EncodedFinancialInstrumentFullName
  data_field(2715, 2716)
  # EncodedLegFinancialInstrumentFullNameLen -> EncodedLegFinancialInstrumentFullName
  data_field(2718, 2719)

  # EncodedUnderlyingFinancialInstrumentFullNameLen -> EncodedUnderlyingFinancialInstrumentFullName
  data_field(2721, 2722)
  # EncodedMatchExceptionTextLen -> EncodedMatchExceptionText
  data_field(2797, 2798)
  # EncodedReplaceTextLen -> EncodedReplaceText
  data_field(2802, 2801)
  # EncodedCancelTextLen -> EncodedCancelText
  data_field(2809, 2808)
  # EncodedPostTradePaymentDescLen -> EncodedPostTradePaymentDesc
  data_field(2815, 2814)
  # EncodedAdditionalTermBondDescLen -> EncodedAdditionalTermBondDesc
  data_field(40004, 40005)
  # EncodedAdditionalTermBondIssuerLen -> EncodedAdditionalTermBondIssuer
  data_field(40008, 40009)
  # EncodedLegStreamTextLen -> EncodedLegStreamText
  data_field(40978, 40979)
  # EncodedLegProvisionTextLen -> EncodedLegProvisionText
  data_field(40980, 40981)
  # EncodedStreamTextLen -> EncodedStreamText
  data_field(40982, 40983)
  # EncodedPaymentTextLen -> EncodedPaymentText
  data_field(40984, 40985)
  # EncodedProvisionTextLen -> EncodedProvisionText
  data_field(40986, 40987)
  # EncodedUnderlyingStreamTextLen -> EncodedUnderlyingStreamText
  data_field(40988, 40989)
  # EncodedDeliveryStreamCycleDescLen -> EncodedDeliveryStreamCycleDesc
  data_field(41083, 41084)

  # EncodedMarketDisruptionFallbackUnderlierSecurityDescLen -> EncodedMarketDisruptionFallbackUnderlierSecurityDesc
  data_field(41101, 41102)
  # EncodedExerciseDescLen -> EncodedExerciseDesc
  data_field(41107, 41108)
  # EncodedStreamCommodityDescLen -> EncodedStreamCommodityDesc
  data_field(41256, 41257)
  # EncodedLegAdditionalTermBondDescLen -> EncodedLegAdditionalTermBondDesc
  data_field(41320, 41321)
  # EncodedLegAdditionalTermBondIssuerLen -> EncodedLegAdditionalTermBondIssuer
  data_field(41324, 41325)
  # EncodedLegDeliveryStreamCycleDescLen -> EncodedLegDeliveryStreamCycleDesc
  data_field(41458, 41459)

  # EncodedLegMarketDisruptionFallbackUnderlierSecurityDescLen -> EncodedLegMarketDisruptionFallbackUnderlierSecurityDesc
  data_field(41476, 41477)
  # EncodedLegExerciseDescLen -> EncodedLegExerciseDesc
  data_field(41482, 41483)
  # EncodedLegStreamCommodityDescLen -> EncodedLegStreamCommodityDesc
  data_field(41653, 41654)
  # EncodedUnderlyingAdditionalTermBondDescLen -> EncodedUnderlyingAdditionalTermBondDesc
  data_field(41710, 41711)
  # EncodedUnderlyingDeliveryStreamCycleDescLen -> EncodedUnderlyingDeliveryStreamCycleDesc
  data_field(41806, 41807)
  # EncodedUnderlyingExerciseDescLen -> EncodedUnderlyingExerciseDesc
  data_field(41811, 41812)

  # EncodedUnderlyingMarketDisruptionFallbackUnderlierSecDescLen -> EncodedUnderlyingMarketDisruptionFallbackUnderlierSecurityDesc
  data_field(41873, 41874)
  # EncodedUnderlyingStreamCommodityDescLen -> EncodedUnderlyingStreamCommodityDesc
  data_field(41969, 41970)
  # EncodedUnderlyingAdditionalTermBondIssuerLen -> EncodedUnderlyingAdditionalTermBondIssuer
  data_field(42025, 42026)
  # EncodedUnderlyingProvisionTextLen -> EncodedUnderlyingProvisionText
  data_field(42171, 42172)
  # LegPaymentStreamFormulaImageLength -> LegPaymentStreamFormulaImage
  data_field(42451, 42452)
  # PaymentStreamFormulaImageLength -> PaymentStreamFormulaImage
  data_field(42652, 42653)
  # UnderlyingPaymentStreamFormulaImageLength -> UnderlyingPaymentStreamFormulaImage
  data_field(42947, 42948)
  # PaymentStreamFormulaLength -> PaymentStreamFormula
  data_field(43109, 42684)
  # LegPaymentStreamFormulaLength -> LegPaymentStreamFormula
  data_field(43110, 42486)
  # UnderlyingPaymentStreamFormulaLength -> UnderlyingPaymentStreamFormula
  data_field(43111, 42982)
end
