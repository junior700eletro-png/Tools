
class AdaptaExtension {
  constructor() {
    this.state = {
      lastCapture: null,
      integrations: [],
      audioActive: false
    };
  }
  
  async updateState() {
    this.state.lastCapture = await captureInterface();
    this.state.integrations = window.adapta.getIntegrations();
    return this.state;
  }
  
  async sendToChat(message) {
    await window.adapta.typeMessage(message);
  }
  
  async reportStatus() {
    const status = await this.updateState();
    console.log('Status atual:', status);
    await this.sendToChat(
      `📊 Status do Ecossistema:\n` +
      `Integrações disponíveis: ${status.integrations.length}\n` +
      `Última captura: ${status.lastCapture.timestamp}`
    );
  }
}

const extension = new AdaptaExtension();
window.adaptaExtension = extension;