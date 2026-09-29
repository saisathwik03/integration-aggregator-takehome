import os

import httpx


class OpenBaoClient:
    def __init__(self):
        self.address = os.getenv(
            "OPENBAO_ADDR",
            "http://127.0.0.1:8200",
        )
        self.token = os.getenv(
            "OPENBAO_TOKEN",
        )

    def write(self, path, data):
        url = self.address + "/v1/" + path

        headers = {
            "X-Vault-Token": self.token,
        }

        response = httpx.post(
            url,
            headers=headers,
            json=data,
        )

        if response.status_code >= 400:
            raise RuntimeError(
                "OpenBao request failed with status "
                + str(response.status_code)
            )

        if response.content:
            return response.json()

        return {}

    def generate_auth_url(
        self,
        server,
        redirect_url,
        state,
    ):
        data = {
            "server": server,
            "redirect_url": redirect_url,
            "state": state,
        }

        return self.write(
            "oauth2/auth-code-url",
            data,
        )

    def save_credential(
        self,
        name,
        code,
        server,
        redirect_url,
    ):
        data = {
            "name": name,
            "code": code,
            "server": server,
            "redirect_url": redirect_url,
        }

        return self.write(
            "oauth2/creds/" + name,
            data,
        )

    def read_credential(self, name):
        url = self.address + "/v1/oauth2/creds/" + name

        headers = {
            "X-Vault-Token": self.token,
        }

        response = httpx.get(
            url,
            headers=headers,
        )

        if response.status_code == 404:
            return None

        if response.status_code >= 400:
            raise RuntimeError(
                "OpenBao request failed with status "
                + str(response.status_code)
            )

        if response.content:
            return response.json()

        return {}