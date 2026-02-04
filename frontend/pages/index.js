import React, { useEffect, useState } from "react";
import axios from "axios";

export default function Home() {
  const [symbol, setSymbol] = useState("CIB");
  const [data, setData] = useState([]);

  const fetchData = async () => {
    try {
      const res = await axios.get(`http://localhost:8000/api/v1/prices/${symbol}`);
      setData(res.data.data || []);
    } catch (e) {
      console.error(e);
      alert("Error fetching data. Ensure the backend is running.");
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  return (
    <div style={{ padding: 20 }}>
      <h1>EGX Analytics (PoC)</h1>
      <div>
        <input value={symbol} onChange={(e) => setSymbol(e.target.value)} />
        <button onClick={fetchData}>Fetch</button>
      </div>
      <pre style={{ maxHeight: 400, overflow: "auto" }}>{JSON.stringify(data.slice(0,20), null, 2)}</pre>
    </div>
  );
}
