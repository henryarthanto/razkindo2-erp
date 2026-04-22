---
Task ID: 1
Agent: Main Agent
Task: Remove Z AI from chat panel, add Kontrak Kerja Karyawan, improve logic

Work Log:
- Rewrote /api/ai/chat/route.ts - removed z-ai-web-dev-sdk, replaced LLM-powered chat with pure logic-based financial analysis
- Added 9 new pure-logic financial analysis handlers: handleHppProfitAnalysis, handleRestockRecommendation, handleSalesTrend, handleCashFlowAudit, handleFinancialHealth, handleCustomerPrediction, handleDebtAnalysis, handleAssetValue, generateSmartResponse
- Created /api/ai/employee-contract/route.ts - new API endpoint for generating employee contract data with company info and employee lookup
- Rewrote AIChatPanel.tsx - removed TTS (which used Z AI), added Kontrak Kerja Karyawan dialog with full PDF generation (Pasal 1-10)
- Updated all welcome messages and header labels to remove "AI" references
- Added quick prompt for "Buat Kontrak Kerja"
- All document PDFs (Penawaran, MOU, Kontrak) include company logo
- Verified linter passes with 0 errors
- Verified dev server compiles and runs correctly

Stage Summary:
- Z AI completely removed from chat panel (chat route + frontend component)
- Kontrak Kerja Karyawan feature fully implemented with professional PDF generation (10 articles)
- Pure logic-based financial analysis replaces LLM-powered analysis
- All changes compile and run without errors
