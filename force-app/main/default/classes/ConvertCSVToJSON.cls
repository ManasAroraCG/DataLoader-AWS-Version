public class ConvertCSVToJSON 
{
    public static List<Object> parseCSV(Blob csvBlob) 
    {
        String csvString = csvBlob.toString();
        List<String> lines = csvString.split('\n');
        List<String> headers = lines[0].split(',');
        List<Object> recordList = new List<Object>();
        
        // Parse CSV lines (start from the second line)
        for (Integer i = 1; i < lines.size(); i++) 
        {
            String line = lines[i];
            List<String> values = line.split(',');
            
            // Create a map for JSON
            Map<String, Object> jsonMap = new Map<String, Object>();
            for (Integer j = 0; j < headers.size(); j++) 
            {
                if (j < values.size()) 
                {
                    jsonMap.put(headers[j].trim(), values[j].trim());
                }
            }
            System.debug(JSON.serialize(jsonMap));
            recordList.add(jsonMap);
            
        }
        
        return recordList;
    }

}