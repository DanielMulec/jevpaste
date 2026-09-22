import JevGateway
import SmartPasteCore
import Testing

@Test func jevGatewayAdapterFillsTheDecisionServiceSeam() {
    let service: any DecisionService = JevGatewayDecisionService()
    #expect(service is JevGatewayDecisionService)
}
